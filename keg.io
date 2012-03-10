#! /usr/bin/env coffee

# Setup dependencies
fs         = require 'fs'
http       = require 'http'
OptParse   = require 'optparse'
sys 				= require 'util'
url 				= require 'url'
path        = require 'path'
querystring = require 'querystring'
io 					= require 'socket.io'
Keg 			  = require './lib/keg'
log4js 			= require 'log4js'
connect 		= require 'connect'
middleware  = require './lib/middleware'
express     = require 'express'

switches = [
  [ "-h", "--help",         'Display the help information' ],
  [ "-f", "--config-file PATH",	'Run with the specified configuration file' ],
  [ '-r', '--rebuild', 'rebuilds the DB, creating a backup of the current DB'],
  [ "-v", "--version",      'Displays the version of keg.io']
]

Options =
  rebuild: false

Parser = new OptParse.OptionParser(switches)
Parser.banner = "Usage keg.io [options]"

Config = null
Parser.on "config-file", (opt, value) ->
  # Load our commented JSON configuration file, stripping out C-style comments
  Config = JSON.parse(fs.readFileSync(value).toString().replace(new RegExp("\\/\\*(.|\\r|\\n)*?\\*\\/", "g"), ""))

Parser.on 'help', (opt, value) ->
  # output the usage info and exit
  console.log Parser.toString()
  process.exit 0

Parser.on 'version', (opt, value) ->
  # output the version info from package.json and exit
  package_path = __dirname + "/package.json"

  fs.readFile package_path, (err,data) ->
    if err
      console.error "Could not open package file : %s", err
      process.exit 1

    content = JSON.parse(data.toString('ascii'))
    console.log content['version']
    process.exit 0

Parser.on 'rebuild', (opt, value) ->
  Options.rebuild = true

Parser.parse process.argv

# defaults, used if no config file is given
unless Config?
  Config =
    socket_listen_port: 8081
    socket_client_connect_port: 8081
    http_port: 8081
    db_path: 'db/kegerator.db'
    high_temp_threshold: 60
    twitter: { enabled: false }

# The logging verbosity (particularly to the console for debugging) can be changed via the
# **conf/log4js.json** configuration file, using standard log4js log levels:
#
#  OFF < FATAL < ERROR < WARN < INFO < DEBUG < TRACE < ALL
logger = log4js.getLogger()
for k, v of Config
  logger.debug "#{k}:#{v}"

# Load access/secret keys from disk:
keys = JSON.parse(fs.readFileSync('conf/keys.json').toString())

keg = new Keg(logger, Config)

rebuild = () ->
  keg.rebuildDb (err) ->
    if err
      console.log "ERROR: #{err}" if err
      process.exit 1
    process.exit 0

if Options.rebuild
  # copy the DB file as .bak, build a new DB
  path.exists Config.db_path, (exists) ->
    if exists
      input = fs.createReadStream Config.db_path
      output = fs.createWriteStream Config.db_path + '.bak'
      sys.pump input, output, (err) ->
        rebuild()
    else
      rebuild()

server = express.createServer()


# ## UI routes
# 'UI' routes are routes designed for keg.io UI clients (eg. web pages) to
# call to interact with the central keg.io server.  The UI routes should respect
# the 'Accepts' header to determine the format of the response, while preferring
# JSON.
#

# ## UI: get the port to use for web socket connections
#   `GET /config/socketPort`
#
server.get '/config/socketPort', (req, res, next) ->
  console.log Config.socket_client_connect_port
  res.send Config.socket_client_connect_port.toString(), 200

# ## UI: get temperatures for a kegerator
#   `GET /kegerators/ACCESS_KEY/temperatures`
#
#    Where **ACCESS_KEY** is the access key of the desired kegerator
#
# Optional params: recent=N
#   where **N** is the number of temperatures to retrieve, in reverse
#   chronological order
#
server.get '/kegerators/:accessKey/temperatures', (req, res, next) ->
  keg.recentTemperatures req.params.accessKey, req.query['recent'], (result) ->
    res.send result, 200

# ## UI: get users for a kegerator, based on recent pours
#   `GET /kegerators/ACCESS_KEY/users`
#
#    Where **ACCESS_KEY** is the access key of the desired kegerator
#
# Optional params: recent=N
#   where **N** is the number of recent pours to retrieve users from
#
server.get '/kegerators/:accessKey/users', (req, res, next) ->
  res.header('Content-Type', 'application/json')
  keg.recentUsers req.params.accessKey, req.query['recent'], (result) ->
    res.send result, 200

# ## UI: get pours for a kegerator
#   `GET /kegerators/ACCESS_KEY/pours`
#
#    Where **ACCESS_KEY** is the access key of the desired kegerator
#     and **N** is the number of pours to retrieve
#
# Optional params: recent=N
#   where **N** is the number of recent pours to retrieve users from
#
# #### Examples:
# ##### Retrieve the last 10 pours for kegerator 1111:
#     GET /1111/recentPours/10
#
server.get '/kegerators/:accessKey/pours', (req, res, next) ->
  keg.recentPours req.params.accessKey, req.query['recent'], (result) ->
    res.send result, 200

# ## UI: get kegs for a kegerator
#   `GET /kegerators/ACCESS_KEY/kegs`
#
#    Where **ACCESS_KEY** is the access key of the desired kegerator
#
# Optional params: recent=N
#   where **N** is the number of temperatures to retrieve, in reverse
#   chronological order
#
server.get '/kegerators/:accessKey/kegs', (req, res, next) ->
  keg.recentKegs req.params.accessKey, req.query['recent'], (result) ->
    res.send result, 200

# ## UI: get info about all users
#   `GET /users`
#

# ## UI: get info about a user
#   `GET /users/RFID/`
#
#    Where **RFID** is the rfid assigned to the desired user
#
server.get '/users/:rfid?', (req, res, next) ->
  keg.users req.params.rfid, (result) ->
    res.send result, 200

# ## UI: get a user's coasters
#   `GET /users/RFID/coasters`
#
#    Where **RFID** is the rfid assigned to the desired user
#
server.get '/users/:rfid/coasters', (req, res, next) ->
  keg.userCoasters req.params.rfid, (result) ->
    res.send result, 200

# ## API routes
# 'API' routes are routes designed for keg.io clients (kegerators, soda machines,
# etc.) to call to interact with the central keg.io server.  All of these routes
# require a signed request, utilizing the access key and secret key that are
# registered with the central keg.io server.
#
# Responses for API routes have a content type of 'text/plain'
#
# ### Signing a request
# - Assemble the 'payload' to be signed:  The payload consists of the following
#   items, concatenated into a single string:
#
#        - Request method, in uppercase (Ex: PUT)
#        - one (1) whitespace character (Ex. ' ')
#        - the hostname to be used for the request, in lowercase (Ex: keg.io)
#        - the path of the request, in lowercase (Ex: /some/path)
#        - the querystring (for GET requests) or form data (for PUT/POST
#          requests), in lowercase, prefixed with a question mark (?) character.
#          If no querystring or form data is being sent, then no question mark
#          is used.
# - Sign the assembled payload, using the secret key assigned to you by keg.io.
#   The signature is calculated using
#   [HMAC SHA256](http://en.wikipedia.org/wiki/HMAC).
#
# - Base64 encode the resulting signature
# - Append the signature to the querystring/data using the key 'signature'
#
# #### Example:
#
# - Payload: 'PUT localhost/api/kegerator/1111/temp/39'
# - Secret: 's3cr3t'
# - Signature: 84f58081ca143ae50f2ead68571da2d6d718f273d8893f2415ee3a70c8c1a20d
# - Request: PUT to http://localhost/api/kegerator/1111/temp/39?signature=84f58081ca143ae50f2ead68571da2d6d718f273d8893f2415ee3a70c8c1a20d
#
#
# API routes adhere to the following HTTP response code conventions:
# - 200: Request was received and processed successfully
# - 400: Bad request syntax, or signature verfification failed
# - 401: Unauthorized.  Unknown access key.
api_middlewares = [middleware.accessKey(), middleware.verify(keys)]

# helper method to format API responses for kegerator clients
respond = (res, actionText, responseText) ->
  res.writeHead 200, {'Content-Type': 'application/json'}
  res.end JSON.stringify({ action: actionText, response: responseText })

# ## API: verify an RFID card
#   `GET /api/kegerator/ACCESS_KEY/scan/RFID?signature=....`
#
#    Where **ACCESS_KEY** is an access key registered with the keg.io server
#    and **RFID** is a the RFID of a valid keg.io user
#
# Requests to this route return 200 if the RFID is valid, and 401 if the RFID
# is unknown to keg.io
#
# #### Examples:
# ##### Authenticate the RFID value 23657ABF5 from kegerator 1111:
#     GET http://keg.io/kegerator/1111/scan/23657ABF5?signature=....
#
server.get '/api/kegerator/:accessKey/scan/:rfid', api_middlewares, (req, res, next) ->
  respond res, 'scan', req.params.rfid

# ## API: report the current flow rate
#   `PUT /api/kegerator/ACCESS_KEY/flow/RATE`
#
#    Where **ACCESS_KEY** is an access key registered with the keg.io server
#    and **RATE** is a the current flow rate of the kegerator in liters/min
#
# #### Examples:
# ##### Report a flow of 12 liters/min on kegerator 1111:
#     PUT http://keg.io/kegerator/1111/flow/12
server.put '/api/kegerator/:accessKey/flow/:rate', api_middlewares, (req, res, next) ->
    respond res, 'flow', req.params.rate

# ## API: report an end to the current flow
#   `PUT /api/kegerator/ACCESS_KEY/flow/end`
#
#    Where **ACCESS_KEY** is an access key registered with the keg.io server
#
# Reports that the flow for the most recent RFID has completed on this
# kegerator
server.put '/api/kegerator/:accessKey/flow/end', api_middlewares, (req, res, next) ->
  respond res, 'flow', 'end'

# ## API: report the current kegerator temperature
#   `PUT /api/kegerator/ACCESS_KEY/temp/TEMP`
#
#    Where **ACCESS_KEY** is an access key registered with the keg.io server
#    and **TEMP** is an integer representing the current keg temperature in F.
#
server.put '/api/kegerator/:accessKey/temp/:temp', api_middlewares, (req, res, next) ->
  respond res, 'temp', req.params.temp

# create the http server, load up our middleware stack, start listening
server.use connect.favicon(__dirname + '/static/favicon.ico', {maxAge: 2592000000})
server.use connect.logger('short')
server.use connect.query() 												# parse query string
server.use middleware.path()											# parse url path
server.use connect.static(__dirname + '/static') 	# static file handling
server.use server.router                          # UI and API routing
server.listen Config.http_port

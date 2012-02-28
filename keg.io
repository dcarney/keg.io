#! /usr/bin/env coffee

# Setup dependencies
fs         = require 'fs'
http       = require 'http'
OptParse   = require 'optparse'
sys 				= require 'util'
url 				= require 'url'
querystring = require 'querystring'
io 					= require 'socket.io'
static 			= require 'node-static'
Keg 			  = require './lib/keg'
log4js 			= require 'log4js'
connect 		= require 'connect'
middleware  = require './lib/middleware'

switches = [
  [ "-h", "--help",         'Display the help information' ],
  [ "-f", "--config-file PATH",	'Run with the specified configuration file' ],
  [ "-d", "--dev-mode",		"Run in 'development' mode: code supplies fake arduino client data to itself"],
  [ '-c', '--clean-mode',	"Run in 'clean' mode: code constantly sends 'open' " +
							'msg to arduino, allowing for easy flushing of ' +
							'kegerator lines' ],
  [ "-v", "--version",      'Displays the version of keg.io']
]

Parser = new OptParse.OptionParser(switches)
Parser.banner = "Usage keg.io [options]"

keg_config = null
Parser.on "config-file", (opt, value) ->
	# Load our commented JSON configuration file, and echo it
	#    strip out C-style comments (/*  */)
	keg_config = JSON.parse(fs.readFileSync(value).toString().replace(new RegExp("\\/\\*(.|\\r|\\n)*?\\*\\/", "g"), ""))

Parser.on "help", (opt, value) ->
  console.log Parser.toString()
  process.exit 0

Parser.on "version", (opt, value) ->
  Options.version = true

Parser.parse process.argv

# The logging verbosity (particularly to the console for debugging) can be changed via the
# **conf/log4js.json** configuration file, using standard log4js log levels:
#
#  OFF < FATAL < ERROR < WARN < INFO < DEBUG < TRACE < ALL
logger = log4js.getLogger();

for k, v of keg_config
	logger.debug "#{k}:#{v}"

# Load access/secret keys from disk:
keys = JSON.parse(fs.readFileSync('conf/keys.json').toString())

keg = new Keg(logger, keg_config)

# routes for UI clients (aka jQuery)
ui_router = (app) =>
  app.get '/user/:id', (req, res, next) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    res.end req.params.id

  app.get '/socketPort.json', (req, res, next) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    res.end keg_config.socket_client_connect_port

  app.get '/currentTemperature.json', (req, res, next) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    res.end keg_config.socket_client_connect_port

  app.get '/temperatureHistory.json', (req, res, next) ->
    keg.getTemperatureTrend (result) ->
      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end result

  app.get '/lastDrinker.json', (req, res, next) ->
    keg.getLastDrinker (result) ->
      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end JSON.stringify({name: 'pour', value: result})

  app.get '/currentPercentRemaining.json', (req, res, next) ->
    keg.getPercentRemaining (percent) ->
      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end JSON.stringify({ name: 'remaining', value: percent + "" })

  app.get '/pourHistory.json', (req, res, next) ->
    keg.getPourTrend (result) ->
      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end result

  app.get '/pourHistoryAllTime.json', (req, res, next) ->
    keg.getPourTrendAllTime (result) ->
      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end result

  app.get '/recentHistory.json', (req, res, next) ->
    keg.getRecentHistory (result) ->
      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end JSON.stringify(result)

# ## API routes
# 'API' routes are routes designed for keg.io clients (kegerators, soda machines,
# etc.) to call to interact with the central keg.io server.  All of these routes
# require a signed request, utilizing the access key and secret key that are
# registered with the central keg.io server.
#
#

# ## Signing a request
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
# - Payload: 'PUT keg.io/some/path?param1=foo&param2=bar'
# - Secret: 'somesupersecretstring'
# - Signature: bcSEesMJCZLUEtskEtdpgXfMeyc-zjO9Uw22FIJwJKQ
# - Request: PUT to http://keg.io/some/path?param1=foo&param2=bar&signature=
#
# All routes that require signature verification return HTTP 400 if the
# request verfication fails.
api_router = (app) =>

  ### API: verify an RFID card
  #   `GET /kegerator/ACCESS_KEY/scan/RFID?signature=....`
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
  ###
  app.get '/kegerator/:accessKey/scan/:rfid', (req, res, next) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    res.end req.params.rfid

  ### API: send the current flow rate
  #   `PUT /kegerator/ACCESS_KEY/flow/RATE`
  #
  #    Where **ACCESS_KEY** is an access key registered with the keg.io server
  #    and **RATE** is a the current flow rate of the kegerator in liters/min
  #
  # #### Examples:
  # ##### Authenticate the RFID value 23657ABF5 from kegerator 1111:
  #     PUT http://keg.io/kegerator/1111/flow/12
  ###
  app.put '/kegerator/:accessKey/flow/:rate', (req, res, next) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    res.end req.params.rate

  # report that the flow for this card ID is done (special case of the above)
  app.put '/kegerator/:accessKey/flow/end', (req, res, next) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    res.end 'FLOW IS DONE!'

  # send the current temperature:
  # :temp indicates the current keg temperature, in F
  app.put '/kegerator/:accessKey/temp/:temp', (req, res, next) ->
    res.writeHead 200, {'Content-Type': 'application/json'}
    res.end JSON.stringify({ temp: req.params.temp })

# create the http server, load up our middleware stack, start listening
server = connect.createServer()
server.use connect.logger()												# log requests
server.use connect.query() 												# parse query string
server.use middleware.path()											# parse url path
server.use '/api', middleware.accessKey()					# parse the accessKey
server.use '/api', middleware.verify(keys)				# verify req signature
server.use connect.static(__dirname + '/static') 	# static file handling
server.use connect.router(ui_router)									# UI routing
server.use '/api', connect.router(api_router)     # API routing
server.listen keg_config.http_port

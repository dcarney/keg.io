#! /usr/bin/env coffee

# Setup dependencies
async       = require 'async'
exec        = require('child_process').exec
express     = require 'express'
fs          = require 'fs'
http        = require 'http'
log4js      = require 'log4js'
moment      = require 'moment'
OptParse    = require 'optparse'
path        = require 'path'
querystring = require 'querystring'
socket_io 	= require 'socket.io'
_           = require 'underscore'
url         = require 'url'
sys         = require 'util'

Keg 			  = require './lib/keg'
middleware  = require './lib/middleware'
KegDb       = require './lib/kegDb'

switches = [
  [ "-h", "--help",         'Display the help information' ],
  [ "-f", "--config-file PATH",	'Run with the specified configuration file' ],
  [ '-r', '--rebuild', 'rebuilds the DB, creating a backup of the current DB'],
  [ "-v", "--version",      'Displays the version of keg.io']
]

defaultConfigPath = 'conf/configuration.json'

# parse the given config file, stripping out C-style comments
parseConfig = (configFilePath) ->
  JSON.parse(fs.readFileSync(configFilePath).toString().replace(new RegExp("\\/\\*(.|\\r|\\n)*?\\*\\/", "g"), ""))

Options =
  rebuild: false

Parser = new OptParse.OptionParser(switches)
Parser.banner = "Usage keg.io [options]"

Config = null
Parser.on "config-file", (opt, value) ->
  # Load our commented JSON configuration file, stripping out C-style comments
  Config = parseConfig value

Parser.on 'help', (opt, value) ->
  # output the usage info and exit
  console.log Parser.toString()
  process.exit 0

Parser.on 'version', (opt, value) ->
  # output the version info from package.json and exit
  package_path = __dirname + "/package.json"

  data = fs.readFileSync package_path
  unless data?
    console.error "Could not open package file : %s", err
    process.exit 1

  content = JSON.parse(data.toString('ascii'))
  console.log "keg.io version #{content['version']}"
  process.exit 0

Parser.on 'rebuild', (opt, value) ->
  Options.rebuild = true

Parser.parse process.argv

# use the default config file, if no override was given
unless Config?
  unless path.existsSync defaultConfigPath
    console.error "#{defaultConfigPath} not found.  Create or specify a different config."
    process.exit 1
  Config = parseConfig defaultConfigPath

# some simple configuration cleansing, to take care of common mistakes
Config.image_host += '/' unless /\/$/.test Config.image_host

# Load access/secret keys from disk:
# unless path.existsSync 'conf/keys.json'
#   console.error 'conf/keys.json not found'
#   process.exit 1
# keys = JSON.parse(fs.readFileSync('conf/keys.json').toString())
keys = JSON.parse(process.env.KEGIO_KEYS)

# The logging verbosity (particularly to the console for debugging) can be changed via the
# **conf/log4js.json** configuration file, using standard log4js log levels:
#
#  OFF < FATAL < ERROR < WARN < INFO < DEBUG < TRACE < ALL
logger = log4js.getLogger()
for k, v of Config
  logger.debug "#{k}:#{v}"

keg = new Keg(logger, Config)

db = new KegDb(Config.mongo, process.env.KEGIO_MONGO_USERNAME, process.env.KEGIO_MONGO_PASSWORD)
db.connect (err) =>
  if err?
    logger.error 'Failed to connect to keg.io DB.'
    logger.error err
    process.exit 1
  else
    logger.info 'Connected to keg.io DB!'

# callback = (err)
rebuild = (callback) ->
  dbName = Config.mongo.db
  # backup
  db.exists dbName, (err, exists) ->
    exists = true
    if err?
      console.error err if err
      process.exit 1
    if exists?
      console.log "backing up #{dbName} to db/bak..."
      # run the following commands in series to back up the DB
      cmds = ["mkdir -p db/bak/"
              "mongodump -h 127.0.0.1:27017 -d #{dbName} --out #{dbName}",
              "tar -czvf db/bak/#{dbName}.tar.gz #{dbName}",
              "rm -rf #{dbName}"]
      workers = []
      _.each cmds, (cmd) ->
        workers.push (cb) ->
          exec cmd, (err, stdout, stderr) ->
            return cb err, {out: stdout, err: stderr} if err?
            cb null, {out: stdout, err: stderr}
      async.series workers, (err, results) ->
        return callback err if err?
        keg.rebuildDb callback  # now do the rebuild

if Options.rebuild
  rebuild (err) ->
    console.log "ERR: #{err}" if err?
    process.exit 1 if err?
    process.exit 0

server = express.createServer()
# the logger middleware has to be added here first, not down with the rest of
# the middleware
server.use express.logger('dev')

# can be used with/without handleResponse
handleError = (err, req, res) ->
  res.contentType 'json'
  responseCode = if err?.responseCode? then err.responseCode else 500
  message =
    message: "Internal error: #{err}"
    error: err
    time: Date.now()
    method: req.method
    query : req.query
    url: req.url
    body: req.body
    headers: req.headers
  res.send(message, responseCode)

handleResponse = (err, result, req, res) ->
  res.contentType 'json'
  if err?
    handleError err, req, res
  else
    res.send result, 200

# ## UI routes
# 'UI' routes are routes designed for keg.io UI clients (eg. web pages) to
# call to interact with the central keg.io server.  The UI routes should respect
# the 'Accepts' header to determine the format of the response, while preferring
# JSON.
#

# ## UI: ping the keg.io server
#   `GET /hello`
#
server.get '/hello', (req, res, next) ->
  respond 200, res, 'world'

# ## UI: get the port to use for web socket connections
#   `GET /config/socketPort`
#
server.get '/config/socketPort', (req, res, next) ->
  # res.send Config.socket_client_connect_port.toString(), 200
  res.send process.env.PORT, 200

# ## UI: get kegerators
#   `GET /kegerators/ID?`
#
#    Where **ID** is the (optional) ID (aka access key) of the desired kegerator
#
# Optional params: limit=N
#   where **N** is the number of temperatures to retrieve, in reverse
#   chronological order
#
server.get '/kegerators/:id?', (req, res, next) ->
  criteria = {}
  criteria['limit'] = req.query['limit']
  criteria['id'] = req.params.id
  keg.db.findKegerators criteria, (err, result) ->
    handleResponse err, result, req, res

# ## UI: get temperatures for a kegerator
#   `GET /kegerators/ID/temperatures`
#
#    Where **ID** is the access key of the desired kegerator
#
# Optional params: limit=N
#   where **N** is the number of temperatures to retrieve, in reverse
#   chronological order
#
server.get '/kegerators/:id/temperatures', (req, res, next) ->
  criteria = {id: req.params.id}
  criteria.limit = req.query['limit']
  keg.db.findTemperatures criteria, (err, result) ->
    handleResponse err, result, req, res

# ## UI: get users for a kegerator, based on recent pours
#   `GET /kegerators/ID/users`
#
#    Where **ID** is the access key of the desired kegerator
#
# Optional params: limit=N
#   where **N** is the number of recent pours to retrieve users from
#
server.get '/kegerators/:id/users', (req, res, next) ->
  criteria = {id: req.params.id}
  criteria.limit = req.query['limit']
  keg.db.findPours criteria, (err, result) ->
    handleError err, req, res if err?
    # lookup up users based on all the RFIDs returned from the result
    criteria = {ids: _.pluck(result, 'rfid')}
    keg.findUsers criteria, (err, result) ->
      handleResponse err, result, req, res

# ## UI: get pours for a kegerator
#   `GET /kegerators/ID/pours`
#
#    Where **ID** is the access key of the desired kegerator
#     and **N** is the number of pours to retrieve
#
# Optional params: limit=N
#   where **N** is the number of recent pours to retrieve users from
#
# #### Examples:
# ##### Retrieve the last 10 pours for kegerator 1111:
#     GET kegerators/1111/pours?limit=10
#
server.get '/kegerators/:id/pours', (req, res, next) ->
  criteria = {id: req.params.id}
  criteria.limit = req.query['limit']
  keg.db.findPours criteria, (err, result) ->
    handleResponse err, result, req, res

# ## UI: get kegs for a kegerator
#   `GET /kegerators/ID/kegs`
#
#    Where **ID** is the access key of the desired kegerator
#
# Optional params: limit=N
#   where **N** is the number of temperatures to retrieve, in reverse
#   chronological order
#
server.get '/kegerators/:id/kegs', (req, res, next) ->
  criteria = {id: req.params.id}
  criteria.limit = req.query['limit']
  keg.db.findKegs criteria, (err, result) ->
    handleResponse err, result, req, res

# ## UI: get info about all users
#   `GET /users/RFID?`
#
# Where **RFID** is the (optional) rfid assigned to the desired user
#
# Optional params: limit=N
#   where **N** is the number of temperatures to retrieve, in reverse
#   chronological order
#
server.get '/users/:rfid?', (req, res, next) ->
  criteria = {}
  criteria['limit'] = req.query['limit']
  criteria['id'] = req.params.rfid
  keg.findUsers criteria, (err, result) ->
    handleResponse err, result, req, res

# ## UI: get info about all of a user's pours
#   `GET /users/RFID/pours`
#
# Where **RFID** is the rfid assigned to the desired user
#
# Optional params: limit=N
#   where **N** is the number of pours to retrieve, in reverse
#   chronological order
#
server.get '/users/:rfid/pours', (req, res, next) ->
  criteria = {rfid: req.params.rfid}
  criteria.limit = req.query['limit']
  keg.db.findPours criteria, (err, result) ->
    handleResponse err, result, req, res

# ## UI: get info about all coasters
#   `GET /coasters`
#
#  Where **ID** is the (optional) ID of the desired coaster
server.get '/coasters/:id?', (req, res, next) ->
  criteria = {}
  criteria['limit'] = req.query['limit']
  criteria['id'] = req.params.id
  keg.findCoasters criteria, (err, result) ->
    handleResponse err, result, req, res

# ## API routes
# 'API' routes are routes designed for keg.io clients (kegerators, soda machines,
# etc.) to call to interact with the central keg.io server.  All of these routes
# require a signed request (see below for details), utilizing the access key and
# secret key that are registered with the central keg.io server.
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
#   The signature is a hex value calculated using
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
# - 404: Unknown resource requested.  Either the kegerator ID was incorrect or an invalid ACTION was specified.
api_middlewares = [middleware.accessKey(), middleware.verify(keys), middleware.removeHeaders(), middleware.captureHeartbeat()]

# helper method to format API responses for kegerator clients
respond = (status_code, res, action_text, response_text) ->
  # content-type for these responses is text/plain, but we don't set the header
  # to cut down on the processing overhead on the arduino
  # res.writeHead status_code, {'Content-Type': 'text/plain'}
  message = "KEGIO:#{action_text}"
  message += ":#{response_text}" if response_text?
  message += ":::"
  res.end message

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
  keg.scanRfid req.params.accessKey, req.params.rfid, (err, valid) ->
    if valid?
      respond(200, res, 'scan', req.params.rfid)
    else
      respond(401, res, 'scan', "#{req.params.rfid} is invalid")


# ## API: report the current flow rate
#   `PUT /api/kegerator/ACCESS_KEY/flow/RATE`
#
#    Where **ACCESS_KEY** is an access key registered with the keg.io server
#    and **RATE** is a the current flow rate of the kegerator in liters/min
#
# This and all subsequent flow requests are associated with the last rfid seen
# on the given kegerator until the special "flow/end" request is received
#
# #### Examples:
# ##### Report a flow of 12 liters/min on kegerator 1111:
#     PUT http://keg.io/kegerator/1111/flow/12
server.put /^\/api\/kegerator\/([\d]+)\/flow\/([\d]+)$/, api_middlewares, (req, res, next) ->
  access_key = req.params[0]
  rate = req.params[1]
  keg.addFlow access_key, rate, (valid) ->
    if valid
      respond(200, res, 'flow', rate)
    else
      respond(401, res, 'flow', 'invalid flow event (a valid scan may not have been received)')

# ## API: report an end to the current flow
#   `PUT /api/kegerator/ID/flow/end`
#
#    Where **ID** is an access key registered with the keg.io server
#
# Reports that the flow for the most recent RFID has completed on this
# kegerator.  Any subsequnt 'flow' requests after this request, but before
# another successful 'scan' request will be ignored.
server.put '/api/kegerator/:id/flow/end', api_middlewares, (req, res, next) ->
  keg.endFlow req.params.id, (err, savedToDb) ->
    if err?
      respond(401, res, 'flow', 'invalid flow event')
    else
      respond(200, res, 'flow', 'end')

# ## API: report the current kegerator temperature
#   `PUT /api/kegerator/ID/temp/TEMP`
#
#    Where **ID** is an access key registered with the keg.io server
#    and **TEMP** is an integer representing the current keg temperature in F.
#
server.put '/api/kegerator/:id/temp/:temp', api_middlewares, (req, res, next) ->
  keg.addTemp req.params.id, req.params.temp, (err, valid) ->
    if err? || not valid
      respond(401, res, 'temp', 'invalid')
    else
      respond(200, res, 'temp', req.params.temp)

# create the http server, load up our middleware stack, start listening

server.use express.favicon(__dirname + '/static/favicon.ico', {maxAge: 2592000000})
server.use express.query() 												# parse query string
server.use middleware.path()											# parse url path
server.use express.static(__dirname + '/static') 	# static file handling
server.use server.router                          # UI and API routing

# server.listen Config.http_port
server.listen process.env.PORT

# dump a list of all the available routes to stdout (for debugging)
#server.routes.all().forEach (route) ->
#  console.log('  \033[90m%s \033[36m%s\033[0m', route.method.toUpperCase(), route.path)

io = socket_io.listen(server)

# This configuration is needed to run on Heroku.
# Websockets aren't supported so we have to use long polling
io.configure ->
  io.set "transports", ["xhr-polling"]
  io.set "polling duration", 10

sendToAllSockets = (event, data) ->
  #logger.debug "pushing #{event} event to all sockets"
  io.sockets.emit event, {data: data}

sendToSocket = (socket, event, data) ->
  #logger.debug "pushing #{event} event to socket #{socket.id}"
  socket.emit event, {data: data}

sendToAttachedSockets = (attachment, event, data) ->
  logger.debug "pushing #{event} event to sockets attached to #{attachment}"
  io.sockets.in(attachment).emit event, {data: data}

# check each known kegerator, and send a socket message indicating it's
# heartbeat "status".
checkHeartbeats = () ->
  now = moment()
  for kegerator_id, momnt of middleware.getHeartbeats()
    alive = now.diff(momnt, 'seconds') <= Config.arduino_hearbeat_threshold_in_sec
    sendToAttachedSockets kegerator_id, 'heartbeat', alive

# run it every 10 seconds
setInterval checkHeartbeats, 10000

keg.on 'scan', (kegerator_id, rfid) ->
  sendToAttachedSockets kegerator_id, 'scan', rfid

keg.on 'pour', (kegerator_id, volume) ->
  sendToAttachedSockets kegerator_id, 'pour', volume

keg.on 'flow', (kegerator_id, rate) ->
  sendToAttachedSockets kegerator_id, 'flow', rate

keg.on 'temp', (kegerator_id, temp) ->
  sendToAttachedSockets kegerator_id, 'temp', temp

keg.on 'deny', (kegerator_id, rfid) ->
  sendToAttachedSockets kegerator_id, 'deny', rfid

keg.on 'coaster', (kegerator_id, coaster) ->
  sendToAttachedSockets kegerator_id, 'coaster', coaster

io.sockets.on 'connection', (socket) ->
  logger.info 'browser client connected'
  sendToSocket socket, 'hello', 'world'

  # events from browser client
  socket.on 'attach', (kegerator_id) ->
    console.log "attach request for #{kegerator_id} on socket #{socket.id}"
    socket.join kegerator_id

    # get all the rooms this socket is joined to
    # ex. { '': true, '/1111': true }
    rooms = io.sockets.manager.roomClients[socket.id]

    # find all the kegerator rooms that aren't the one we're attaching to
    otherRooms = _.filter _.keys(rooms), (room) ->
      room.match(/\/\d+/) && room != "/#{kegerator_id}"

    # leave other kegerator's rooms
    _.each otherRooms, (room) ->
      roomId = room.replace /^\//, '' # remove leading '/'
      console.log "leaving #{roomId}..."
      socket.leave roomId

    console.log io.sockets.manager.roomClients[socket.id]
    console.log "attached to #{kegerator_id}"
    socket.emit 'attached'

  socket.on 'detach', () ->
    console.log "detach request for socket #{socket.id}"

    # get all the rooms this socket is joined to
    # ex. { '': true, '/1111': true }
    rooms = io.sockets.manager.roomClients[socket.id]

    # leave them all
    _.each _.keys(rooms), (room) ->
      console.log "room"
      console.log room
      roomId = room.replace /^\//, '' # remove leading '/'
      console.log "leaving #{roomId}..."
      socket.leave roomId

    socket.emit 'detached'

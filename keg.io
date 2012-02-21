#! /usr/bin/env coffee

## About
# **keg.io** is a techonology-laden kegerator, developed by VNC employees, to
# satisfy their nerdiest beer-drinking needs.  It's built on node.js, and utilizes
# an arduino microcontroller for interfacing with the actual keg HW and sensors.
#
#  It's got several cool features, including:
#
#  * Gravatar support
#  * Twitter integration
#
# **keg.io** accepts two types of clients: web browser and kegerator.
#
# A web browser client connects to keg.io to view its primary GUI.
# A kegerator client connects to keg.io to send and receive sensor information.
#
# Keg.io can accept multiple connections from both web browsers and kegerators.

# Setup dependencies
fs         = require 'fs'
http       = require 'http'
OptParse   = require 'optparse'
sys 				= require 'util'
url 				= require 'url'
querystring = require 'querystring'
io 					= require 'socket.io'
static 			= require 'node-static'
keg_io 			= require './lib/keg.io/keg.io'
log4js 			= require 'log4js'
connect 		= require 'connect'
middleware  = require './lib/keg.io/middleware'
url					= require 'url'

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

keg = new keg_io.Keg()
keg.init(logger,
		 		 keg_config.device,
				 keg_config.db_name,
				 keg_config.twitter_enabled,
				 keg_config.twitter_consumer_key,
				 keg_config.twitter_consumer_secret,
				 keg_config.twitter_access_token_key,
				 keg_config.twitter_access_token_secret,
				 keg_config.admin_ui_password,
				 keg_config.high_temp_threshold)

router = (app) =>
  app.get('/user/:id', (req, res, next) ->
    res.writeHead(200, {'Content-Type': 'text/plain'})
    res.end(req.params.id))

  app.get('/admin/:id', (req, res, next) ->
    res.writeHead(200, {'Content-Type': 'text/plain'})
    res.end("ADMIN!" + req.params.id + req.params.sig))

  app.get('/socketPort.json', (req, res, next) ->
	  res.writeHead(200, {'Content-Type': 'text/plain'})
	  res.end(keg_config.socket_client_connect_port))

  app.get('/currentTemperature.json', (req, res, next) ->
	  res.writeHead(200, {'Content-Type': 'text/plain'})
	  res.end(keg_config.socket_client_connect_port))

  app.get('/temperatureHistory.json', (req, res, next) ->
  	keg.getTemperatureTrend((result) ->
	  	res.writeHead(200, {'Content-Type': 'text/plain'})
	  	res.end(result)))

  app.get('/lastDrinker.json', (req, res, next) ->
    keg.getLastDrinker((result) ->
        res.writeHead(200, {'Content-Type': 'text/plain'})
        res.end(JSON.stringify({name: 'pour', value: result}))))


# create the http server, load up our middleware stack, start listening
server = connect.createServer()
server.use connect.logger()												# log requests
server.use connect.query() 												# parse query string
server.use middleware.path()											# parse url path
server.use middleware.verify()										# verify req signature
server.use connect.static(__dirname + '/static') 	# static file handling
server.use connect.router(router)									# routing
server.listen keg_config.http_port

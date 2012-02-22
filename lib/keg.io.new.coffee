# The 'main' server-side class
#
# The KegIo object is an event emitter, and serves as the primary object with
# which the keg.io server code interacts. This object encapsulates and maintains
# the necessary ojbects for working with the DB and Twitter functionality.
#
fs        = require 'fs'
sys       = require 'util'
util      = require if process.binding('natives').util then 'util' else 'sys'
keg_db    = require './keg.db'
keg_tweet = require './keg.tweet'
crypto    = require 'crypto'
socketio  = require 'socket.io'
http      = require 'http'

class Keg
  constructor: (logger, config) ->
    process.EventEmitter.call(this)
    @actions = ['TAG', 'TEMP', 'FLOW']
    @lastRfidSeen = null
    @lastTempSeen = null
    @websocketPort = null
    @totalFlowAmount = 0.0
    @lastFlowTime = null
    @logger = logger;
    @adminUiPassword = config.adminUiPassword;
    @highTempThreshold = config.highTempThreshold;

    @kegDb = new keg_db.KegDb
    @kegDb.initialize(@logger, config.db_name);

    if config.twitter.enabled
      # Initialize the Twitter module, passing in all the necessary config
      # values (that represent our API keys)
      @kegTwit = new keg_tweet.KegTwit(@logger, config.twitter)

  formatPourTrend: (rows, callback) ->
    formattedData = []
    if (rows)
      for row in rows
        formattedData.push( [row.first_name + " " + row.last_name, row.volume ] )
    data = JSON.stringify({ name: 'pourHistory', value: formattedData });
    callback(data)

  getPourTrend: (callback) ->
    #self = this
    @kegDb.getActiveKeg (rows) =>
      if rows && rows.length > 0
        @kegDb.getPourTotalsByUserByKeg rows[0].keg_id, (rows) =>
          @formatPourTrend(rows, callback)

  getPourTrendAllTime: (callback) ->
    @kegDb.getPourTotalsByUser (rows) =>
      @formatPourTrend(rows, callback)

  getRecentHistory: (callback) ->
    @kegDb.getRecentHistory (rows) ->
      callback JSON.stringify(rows)

module.exports = Keg
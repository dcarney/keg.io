# The 'main' server-side class
#
# The KegIo object is an event emitter, and serves as the primary object with
# which the keg.io server code interacts. This object encapsulates and maintains
# the necessary ojbects for working with the DB and Twitter functionality.
#
fs          = require 'fs'
sys         = require 'util'
events      = require 'events'
util        = require if process.binding('natives').util then 'util' else 'sys'
KegTwitter  = require './keg.twitter'
socketio    = require 'socket.io'
http        = require 'http'
moment      = require 'moment'
async       = require 'async'
_           = require 'underscore'

DbRebuild   = require './dbrebuild'
KegDb       = require './kegDb'
Pour        = require './models/pour'
User        = require './models/user'
Temperature = require './models/temperature'

class Keg extends events.EventEmitter
  constructor: (logger, config) ->
    events.EventEmitter.call this
    @logger = logger;
    @adminUiPassword = config.adminUiPassword
    @highTempThreshold = config.highTempThreshold
    @config = config

    @db = new KegDb(@config.mongo)
    @db.connect (err) =>
      @db.findKeg 1, (err, keg) ->
      console.log "ERR" if err?

    # a hash of kegerator access keys to the last RFIDs seen at each
    # Ex. { 1111 => 1234FFE429,
    #       2222 => 999FFF1233 }
    @kegerator_last_scans = {}

    mapAttribValues: (model) ->
       (model[attr_name] for attr_name in model.attributes)

    # map all the attributes of the object (as defined by model.attributes),
    # except those contained in 'excludes'.  Additionally, any top-level
    # properties of model contained in 'includes' will be included
    mapAttribs:(model, excludes = [], includes = []) ->
      result = {}
      for attr_name in model.attributes
        result[attr_name] = model[attr_name] unless excludes.indexOf(attr_name) > -1
      for attr_name in includes
        result[attr_name] = model[attr_name] if model[attr_name]?
      result

    # associations
    #@models.Kegerator.hasMany(@models.Keg, {foreignKey: 'kegerator_id'})
    #@models.Kegerator.hasMany(@models.Temperature, {foreignKey: 'kegerator_id'})
    #@models.Keg.hasMany(@models.Pour, {foreignKey: 'keg_id'})
    #@models.User.hasMany(@models.Pour, {foreignKey: 'rfid'})
    #@models.Coaster.hasMany(@models.User)
    #@models.User.hasMany(@models.Coaster)

    if config? && config.twitter? && config.twitter.enabled
      # Initialize the Twitter module, passing in all the necessary config
      # values (that represent our API keys)
      @kegTwit = new KegTwitter(@logger, config.twitter)

  rebuildDb: (cb) =>
    console.log 'Rebuilding the keg.io DB...'
    rebuilder = new DbRebuild()
    rebuilder.rebuild @config.mongo.db, @config.mongo.servers[0].host, @config.mongo.servers[0].port, cb

  # cb = (err, valid)
  # emits: 'scan' or 'deny'
  scanRfid: (access_key, rfid, cb) =>
    rfid = rfid.toUpperCase()
    @db.findUser rfid, (err, user) =>
      return cb err, null if err?
      valid = user? && user.rfid == rfid
      # store a pour obj to use w/ future flow events
      # TODO: Add the current keg id to the pour event
      if valid
        @kegerator_last_scans[access_key] = new Pour {rfid: rfid, keg_id: 1} # TODO: this shouldn't be hardcoded
        @emit 'scan', access_key, rfid
      else
        @emit 'deny', access_key, rfid
        # invalid rfid; delete any Pour object we might have had for that kegerator
        delete @kegerator_last_scans[access_key]
      cb null, valid

  # cb = (valid)
  addFlow: (access_key, rate, cb) =>
      pour = @kegerator_last_scans[access_key]
      if pour?
        @emit 'flow', access_key, rate
        @kegerator_last_scans[access_key].addFlow rate
      cb(pour?)

  # cb = (err, savedToDb)
  # emits: 'pour'
  endFlow: (access_key, cb) =>
    pour = @kegerator_last_scans[access_key]
    return cb 'no valid pour event to end', null unless pour?

    # remove the pour obj from memory, calculate the total volume of the pours,
    # and save to the DB and emit if > 0
    delete @kegerator_last_scans[access_key]
    volume = pour.calculateVolume()
    if volume <= 0
      return cb null, false
    else
      @db.saveObjects 'pours', pour, (err, result) =>
        return cb err, false if err?
        @emit 'pour', access_key, volume

        # Gather beer and user info from the DB
        #kegDb.getActiveKeg(function(rows){

        # Tweet about it, whydoncha
        #@kegTwit.tweetPour userInfo, ounces, beerInfo
        cb null, true

  # cb = (err, savedToDb)
  # emits 'temp'
  addTemp: (access_key, temp, cb) ->
    t = new Temperature({temperature: temp, kegerator_id: access_key})
    @db.saveObjects 'temperatures', t, (err, result) =>
      return cb err, false if err?
      @emit 'temp', access_key, temp
      cb null, true

  # cb= (err, result)
  findUser: (rfid, cb) =>
    @db.findUser rfid, (err, user) =>
      return cb err, null if err?
      u = new User user
      u.getGravatar (gravatar_url) ->
        u.gravatar = gravatar_url
        cb null, u

  # criteria = 0 or more of: {id, limit, kegerator_id}
  # cb= (err, result)
  findUsers: (criteria, cb) =>
    @db.findUsers criteria, (err, users) =>
      return cb err, null if err?
      # fn to be used w/ async.map
      # cb = (err, user')
      mapUser = (user, cb) ->
        u = new User user
        u.getGravatar (gravatar_url) ->
          u.gravatar = gravatar_url
          cb null, u
      async.map users, mapUser, cb

  # cb = (err, results)
  findCoasters: (criteria, cb) =>
    @db.findCoasters criteria, (err, coasters) =>
      return cb err, null if err?
      cb null, _.map coasters, (coaster) =>
        coaster.image_path = "#{@config.image_host}#{coaster.image_path}"
        coaster

   kegerators: (num_kegerators, cb) ->
    query = {order: 'created_at DESC'}
    query.limit = num_kegerators if num_kegerators?
    @models.Kegerator.findAll(query).success (kegerators) =>
      cb(@models.mapAttribs(kegerator, ['owner_email', 'id', 'updated_at']) for kegerator in kegerators)

  kegeratorTemperatures: (access_key, num_temps, cb) ->
    @models.Kegerator.find({where: {access_key: access_key}}).success (kegerator) =>
      query = {where: {kegerator_id: kegerator.access_key}}
      query.limit = num_temps if num_temps?
      @models.Temperature.findAll(query).success (temps) =>
        cb(@models.mapAttribs(temp) for temp in temps)

  kegeratorKegs: (access_key, num_kegs, cb) ->
    @models.Kegerator.find({where: {access_key: access_key}}).success (kegerator) =>
      query = {where: {kegerator_id: kegerator.id}, order: 'tapped_date DESC'}
      query.limit = num_kegs if num_kegs?
      @models.Keg.findAll(query).success (kegs) =>
        kegs = (@models.mapAttribs(k) for k in kegs)
        for k in kegs
          k.image_path = "#{@config.image_host}#{k.image_path}"
        cb(kegs)

  kegeratorUsers: (access_key, num_pours, cb) ->
    @kegeratorPours access_key, num_pours, (pours) =>
      cb('') unless pours? && pours.length >= 1
      rfids = pours.map (pour) -> pour.rfid
      @models.User.findAll({where: {rfid: rfids}}).success (users) =>
        cb(@models.mapAttribs(user) for user in users)

  kegeratorPours: (access_key, num_pours, cb) ->
    @db.findPours access_key, num_pours, (err, coasters) =>
      return cb err, null if err?
      cb null, _.map coasters, (coaster) =>
        coaster.image_path = "#{@config.image_host}#{coaster.image_path}"
        coaster

    suffix = if num_pours then "LIMIT #{num_pours}" else ''
    @models.Kegerator.find({where: {access_key: access_key}}).success (kegerator) =>
      sql = "SELECT * FROM `pours` p " +
            "INNER JOIN `kegs` k on p.keg_id = k.id " +
            "INNER JOIN `kegerators` ke ON ke.id = k.kegerator_id " +
            "WHERE ke.access_key=#{kegerator.access_key} " +
            "ORDER BY p.created_at DESC #{suffix};"
      ###
      @sequelize.query(sql, @models.Pour).on 'success', (pours) =>
        cb(@models.mapAttribs(pour) for pour in pours)
      ###

  userCoasters: (rfid, cb) ->
    @models.User.find({where: {rfid: rfid}}).success (user) =>
      user.getCoasters().on 'success', (coasters) =>
        cb(@models.mapAttribs(coaster) for coaster in coasters)

module.exports = Keg
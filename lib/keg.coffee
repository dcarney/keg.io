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
keg_db      = require './keg.db'
KegTwitter  = require './keg.twitter'
socketio    = require 'socket.io'
http        = require 'http'
Sequelize   = require 'sequelize'
new_db      = require './keg.db.coffee'
moment      = require 'moment'
async       = require 'async'

class Keg extends events.EventEmitter
  constructor: (logger, config) ->
    events.EventEmitter.call this
    @logger = logger;
    @adminUiPassword = config.adminUiPassword
    @highTempThreshold = config.highTempThreshold
    @config = config

    # a hash of kegerator access keys to the last RFIDs seen at each
    # Ex. { 1111 => 1234FFE429,
    #       2222 => 999FFF1233 }
    @kegerator_last_scans = {}

    #@kegDb = new keg_db.KegDb
    #@kegDb.initialize(@logger, config.db_path);

    @sequelize = new Sequelize '', '', '', {
      dialect: 'sqlite',
      storage: config.db_path,
      logging: false
    }

    # wrap all of our model imports into a "namespace"
    @models =
      Kegerator: @sequelize.import "#{__dirname}/models/kegerator.coffee"
      Keg: @sequelize.import "#{__dirname}/models/keg.coffee"
      User: @sequelize.import "#{__dirname}/models/user.coffee"
      Pour: @sequelize.import "#{__dirname}/models/pour.coffee"
      Temperature: @sequelize.import "#{__dirname}/models/temperature.coffee"
      Coaster: @sequelize.import "#{__dirname}/models/coaster.coffee"

    ###
    { attributes:
     [ 'rfid',
       'first_name',
       'last_name',
       ... ],
    ...
    ...
    rfid: '440055F873',
    first_name: 'Garrett',
    last_name: 'Patterson',
    ...
    ###
    @models.mapAttribValues = (model) ->
       (model[attr_name] for attr_name in model.attributes)

    # map all the attributes of the object (as defined by model.attributes),
    # except those contained in 'excludes'.  Additionally, any top-level
    # properties of model contained in 'includes' will be included
    @models.mapAttribs = (model, excludes = [], includes = []) ->
      result = {}
      for attr_name in model.attributes
        result[attr_name] = model[attr_name] unless excludes.indexOf(attr_name) > -1
      for attr_name in includes
        result[attr_name] = model[attr_name] if model[attr_name]?
      result

    # associations
    @models.Kegerator.hasMany(@models.Keg, {foreignKey: 'kegerator_id'})
    @models.Kegerator.hasMany(@models.Temperature, {foreignKey: 'kegerator_id'})
    @models.Keg.hasMany(@models.Pour, {foreignKey: 'keg_id'})
    @models.User.hasMany(@models.Pour, {foreignKey: 'rfid'})
    @models.Coaster.hasMany(@models.User)
    @models.User.hasMany(@models.Coaster)

    if config? && config.twitter? && config.twitter.enabled
      # Initialize the Twitter module, passing in all the necessary config
      # values (that represent our API keys)
      @kegTwit = new KegTwitter(@logger, config.twitter)

  rebuildDb: (cb) ->
    console.log 'Rebuilding the keg.io DB...'
    @sequelize.sync({force: true}).success () =>
      console.log '...DB rebuild complete'
      console.log 'Populating the keg.io DB...'
      new_db.populate @models, (err) ->
        throw err if err
        console.log '...DB population complete'
        cb()
      .error (error) ->
        cb(error)

  scanRfid: (access_key, rfid, cb) ->
    @models.User.findAll({where: {rfid: rfid}}).success (user) =>
      valid = user? && user.length > 0
      # store pour info for future pour events
      # TODO: Add the current keg id to the pour event
      if valid
        @kegerator_last_scans[access_key] = @models.Pour.build({
          rfid: rfid
          keg_id: 1
          volume_ounces: 0
          })
        @emit 'scan', access_key, rfid
      else
        # invalid rfid; delete any Pour object we might have had for that kegerator
        delete @kegerator_last_scans[access_key]
      cb(valid)

  endFlow: (access_key, cb) ->
    pour = @kegerator_last_scans[access_key]
    unless pour?
      cb('no valid pour event to end')
    else
      # remove the pour obj from memory, calculate the total volume of the pours,
      # and save to the DB if > 0
      delete @kegerator_last_scans[access_key]
      volume = pour.calculateVolume()
      if  volume > 0
        @emit 'pour', access_key, volume
        pour.save().error( (err) -> cb(err) ).success () -> cb()
      else
        cb() # no-op

  addFlow: (access_key, rate, cb) ->
      valid = @kegerator_last_scans[access_key]?
      if valid
        @emit 'flow', access_key, rate
        @kegerator_last_scans[access_key].addFlow rate
      cb(valid)

  addTemp: (access_key, temp, cb) ->
      @models.Temperature.build({
        temperature: temp,
        kegerator_id: access_key}).save().success () ->
        @emit 'temp', access_key, temp
        cb(true)

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
    suffix = if num_pours then "LIMIT #{num_pours}" else ''
    @models.Kegerator.find({where: {access_key: access_key}}).success (kegerator) =>
      sql = "SELECT * FROM `pours` p " +
            "INNER JOIN `kegs` k on p.keg_id = k.id " +
            "INNER JOIN `kegerators` ke ON ke.id = k.kegerator_id " +
            "WHERE ke.access_key=#{kegerator.access_key} " +
            "ORDER BY p.created_at DESC #{suffix};"
      @sequelize.query(sql, @models.Pour).on 'success', (pours) =>
        cb(@models.mapAttribs(pour) for pour in pours)

  # a thin 'wrapper' around the user.emailHash method, for user with the
  # async.map call below.  There's probably a cleaner way to do this...
  getUserGravatar: (user, cb) ->
    user.emailHash (hash) ->
      user.gravatar = "http://www.gravatar.com/avatar/#{hash}?s=256"
      user.hash = hash
      cb(null, user)

  users: (rfid, cb) =>
    query = if rfid? then {where: {rfid: rfid}} else {}
    @models.User.findAll(query).success (users) =>
      async.map users, @getUserGravatar, (err) =>
        cb(@models.mapAttribs(user, ['email'], ['gravatar', 'hash']) for user in users)

  userCoasters: (rfid, cb) ->
    @models.User.find({where: {rfid: rfid}}).success (user) =>
      user.getCoasters().on 'success', (coasters) =>
        cb(@models.mapAttribs(coaster) for coaster in coasters)

  coasters: (id, cb) ->
    query = if id? then {where: {id: id}} else {}
    @models.Coaster.findAll(query).success (coasters) =>
      cstrs = (@models.mapAttribs(coaster) for coaster in coasters)
      for cstr in cstrs
        cstr.image_path = "#{@config.image_host}#{cstr.image_path}"
      cb(cstrs)

module.exports = Keg
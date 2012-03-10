# The 'main' server-side class
#
# The KegIo object is an event emitter, and serves as the primary object with
# which the keg.io server code interacts. This object encapsulates and maintains
# the necessary ojbects for working with the DB and Twitter functionality.
#
fs          = require 'fs'
sys         = require 'util'
util        = require if process.binding('natives').util then 'util' else 'sys'
keg_db      = require './keg.db'
KegTwitter  = require './keg.twitter'
socketio    = require 'socket.io'
http        = require 'http'
Sequelize   = require 'sequelize'
new_db      = require './keg.db.coffee'

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

    # map all the attributes of the object, except those contained
    # in 'excludes'
    @models.mapAttribs = (model, excludes = []) ->
      result = {}
      for attr_name in model.attributes
        result[attr_name] = model[attr_name] unless excludes.indexOf(attr_name) > -1
      result

    # associations
    @models.Kegerator.hasMany(@models.Keg, {foreignKey: 'kegerator_id'})
    @models.Kegerator.hasMany(@models.Temperature, {foreignKey: 'kegerator_id'})
    @models.Keg.hasMany(@models.Pour, {foreignKey: 'keg_id'})
    @models.User.hasMany(@models.Pour, {foreignKey: 'user_id'})
    @models.User.hasMany(@models.Coaster)
    @models.Coaster.hasMany(@models.User)

    if config? && config.twitter? && config.twitter.enabled
      # Initialize the Twitter module, passing in all the necessary config
      # values (that represent our API keys)
      @kegTwit = new KegTwitter(@logger, config.twitter)
      @kegTwit.tweet 'Hello world...'

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

  recentTemperatures: (access_key, num_temps, cb) ->
    @models.Kegerator.find({where: {access_key: access_key}}).success (kegerator) =>
      query = {where: {kegerator_id: kegerator.access_key}}
      query.limit = num_temps if num_temps?
      @models.Temperature.findAll(query).success (temps) =>
        cb(@models.mapAttribs(temp) for temp in temps)

  recentKegs: (access_key, num_kegs, cb) ->
    @models.Kegerator.find({where: {access_key: access_key}}).success (kegerator) =>
      query = {where: {kegerator_id: kegerator.access_key}, order: 'tapped_date DESC'}
      query.limit = num_kegs if num_kegs?
      @models.Keg.findAll(query).success (kegs) =>
        cb(@models.mapAttribs(keg) for keg in kegs)

  recentUsers: (access_key, num_pours, cb) ->
    @recentPours access_key, num_pours, (pours) =>
      cb('') unless pours? && pours.length >= 1
      rfids = pours.map (pour) -> pour.rfid
      console.log rfids
      @models.User.findAll({where: {rfid: rfids}}).success (users) =>
        cb(@models.mapAttribs(user) for user in users)

  recentPours: (access_key, num_pours, cb) ->
    suffix = if num_pours then "LIMIT #{num_pours}" else ''
    @models.Kegerator.find({where: {access_key: access_key}}).success (kegerator) =>
      sql = "SELECT * FROM `pours` p " +
            "INNER JOIN `kegs` k on p.keg_id = k.id " +
            "INNER JOIN `kegerators` ke ON ke.access_key = k.kegerator_id " +
            "WHERE ke.access_key=#{kegerator.access_key} " +
            "ORDER BY p.pour_date DESC #{suffix};"
      @sequelize.query(sql, @models.Pour).on 'success', (pours) =>
        cb(@models.mapAttribs(pour) for pour in pours)

  lastDrinker: (access_key, cb) ->
    @recentPours access_key, 1, (pours) =>
      cb '' unless pours && pours.length == 1
      @models.User.find({where: {rfid: pours[0].rfid}}).success (user) =>
        result = @models.mapAttribs user
        user.emailHash (hash) ->
          result['hash'] = hash
          cb result

  users: (rfid, cb) ->
    query = if rfid? then {where: {rfid: rfid}} else {}
    @models.User.findAll(query).success (users) =>
      cb(@models.mapAttribs(user, ['email']) for user in users)

  userCoasters: (rfid, cb) ->
    @models.User.find({where: {rfid: rfid}}).success (user) =>
      user.getCoasters().on 'success', (coasters) =>
        cb(@models.mapAttribs(coaster) for coaster in coasters)

  getLastDrinker: (callback) ->
    @kegDb.getLastDrinker (rows) =>
      callback null unless rows? && rows.length > 0
      #Hash the email, then send an event to the UI with the relevant data
      @hashEmail rows[0].email, (hash) ->
        callback(JSON.stringify(
            {
              'first_name': rows[0].first_name,
              'last_name': rows[0].last_name,
              'nickname': rows[0].nickname,
              'hash': hash,
              'email': rows[0].email,
              'usertag': rows[0].rfid,
              'twitter_handle': rows[0].twitter_handle,
              'pouring': false,
              'member_since': rows[0].member_since,
              'num_pours': rows[0].num_pours
              }))

module.exports = Keg
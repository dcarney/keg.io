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
Untappd     = require './untappd.coffee'
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
Coaster     = require './models/coaster'

class Keg extends events.EventEmitter
  constructor: (logger, @config) ->
    events.EventEmitter.call this
    @logger = logger;
    @adminUiPassword = config.adminUiPassword
    @highTempThreshold = config.highTempThreshold

    @db = new KegDb(@config.mongo, process.env.KEGIO_MONGO_USERNAME, process.env.KEGIO_MONGO_PASSWORD)
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

    if config? && config.twitter? && config.twitter.enabled
      # Initialize the Twitter module, passing in all the necessary config
      # values (that represent our API keys)
      @kegTwit = new KegTwitter(@logger, config.twitter)
      
    if config? && config.untappd
      @untappd = new Untappd(@logger, config.untappd)

  rebuildDb: (cb) =>
    console.log 'Rebuilding the keg.io DB...'
    rebuilder = new DbRebuild()
    rebuilder.rebuild @config.mongo.db, @config.mongo.servers[0].host, @config.mongo.servers[0].port, cb

  # cb = (err, valid)
  # emits: 'scan' or 'deny'
  scanRfid: (kegerator_id, rfid, cb) =>
    rfid = rfid.toUpperCase()
    @db.findUser rfid, (err, user) =>
      return cb err, null if err?
      valid = (user? && (user.rfid == rfid))
      # store a pour obj to use w/ future flow events
      # TODO: Add the current keg id to the pour event
      if valid
        kegerator_id = parseInt kegerator_id, 10 if _.isString kegerator_id
        @kegerator_last_scans[kegerator_id] = rfid
        @emit 'scan', kegerator_id, rfid
      else
        @emit 'deny', kegerator_id, rfid
        # invalid rfid; delete any Pour object we might have had for that kegerator
        delete @kegerator_last_scans[kegerator_id]
      cb null, valid

  # emits: 'coaster' if new coaster(s) is/are earned
  checkForNewCoasters: (pour, volume) =>
    @logger.info "checking for new coasters"

    ## get the user's current coasters
    @db.findUser pour.rfid, (err, user) =>
      user.coasters ?= []

      # get the user's pour history
      @db.findPours {rfid: pour.rfid}, (err, pours) =>

        # helper fn
        saveCoaster = (user, coaster) =>
          user.coasters.push coaster
          @db.update 'users', {rfid: user.rfid}, {$set: {coasters: user.coasters}}, () ->

        # welcome coaster
        unless _.include user.coasters, Coaster.WELCOME
          @logger.info "#{user.rfid} just earned the 'Welcome' coaster!"
          @db.findCoasters {id: Coaster.WELCOME}, (err, coaster) =>
            @emit 'coaster', pour.kegerator_id, coaster unless err?
            saveCoaster user, Coaster.WELCOME

        # early bird coaster
        unless _.include user.coasters, Coaster.EARLY_BIRD
          if moment().hours() < 15  # 3PM
            @logger.info "#{user.rfid} just earned the 'Early Bird' coaster!"
            @db.findCoasters {id: Coaster.EARLY_BIRD}, (err, coaster) =>
              @emit 'coaster', pour.kegerator_id, coaster unless err?
              saveCoaster user, Coaster.EARLY_BIRD

        # party starter coaster
        unless _.include user.coasters, Coaster.PARTY_STARTER
          criteria = {id: pour.kegerator_id, limit: 2}
          # Get last 2 pours for this kegerator (1 is the current pour)
          @db.findPours criteria, (err, pours) =>
            now = moment()
            bothPoursToday = _.all pours, (pour) ->
              moment(pour.date).date() == now.date() &&
              moment(pour.date).month() == now.month() &&
              moment(pour.date).year() == now.year()
            unless bothPoursToday
              @logger.info "#{user.rfid} just earned the 'Party Starter' coaster!"
              @db.findCoasters {id: Coaster.PARTY_STARTER}, (err, coaster) =>
                @emit 'coaster', pour.kegerator_id, coaster unless err?
                saveCoaster user, Coaster.PARTY_STARTER

        # off the wagon coaster: 3 weeks since the user's past pour
        unless _.include user.coasters, Coaster.OFF_THE_WAGON
          off_the_wagon = false
          if pours.length > 1
            off_the_wagon = moment(pours[0].date).diff(moment(pours[1].date), 'weeks', true) >= 3.0
          if off_the_wagon
            @logger.info "#{user.rfid} just earned the 'Off the Wagon' coaster!"
            @db.findCoasters {id: Coaster.OFF_THE_WAGON}, (err, coaster) =>
              @emit 'coaster', pour.kegerator_id, coaster unless err?
              saveCoaster user, Coaster.OFF_THE_WAGON

        # take the bus home coaster: 48 ounces poured in the last hour
        unless _.include user.coasters, Coaster.TAKE_THE_BUS_HOME
          now = moment()
          ONE_HOUR = 60 * 60 * 1000 # 1 hour in ms
          # helper fn - sums the volume of pours that occurred in the last hour
          reducer = (total, pour) ->
            if now.diff(moment(pour.date), 'hours', true) <= 1.0 then total + pour.volume_ounces else total
          hour_volume = _.reduce pours, reducer, 0
          if hour_volume >= 48
            @logger.info "#{user.rfid} just earned the 'Take the Bus Home' coaster!"
            @db.findCoasters {id: Coaster.TAKE_THE_BUS_HOME}, (err, coaster) =>
              @emit 'coaster', pour.kegerator_id, coaster unless err?
              saveCoaster user, Coaster.TAKE_THE_BUS_HOME

  # cb = (err, savedToDb)
  # emits: 'pour'
  endFlow: (kegerator_id, volume, cb) =>
    rfid = @kegerator_last_scans[kegerator_id]
    return cb 'no valid pour event to end', null unless rfid?

    # remove the rfid from memory, and save the pour to the DB and emit if > 0
    delete @kegerator_last_scans[kegerator_id]

    pour =
      date: moment().format 'YYYY-MM-DDTHH:mm:ssZ' #ISO8601
      rfid: rfid
      keg_id: 1   # TODO: hardcoded
      kegerator_id: parseInt kegerator_id, 10
      volume_ounces: parseInt volume, 10

    # save to the DB and emit
    # if pour_volume < 0, set it to 0 and also don't check for new costers
    if volume <= 0
      pour.volume_ounces = 0
      @db.insertObjects 'pours', pour, (err, result) =>
        return cb err, false if err?
        @emit 'pour', kegerator_id, 0
        cb null, true
    else
      @db.insertObjects 'pours', pour, (err, result) =>
        return cb err, false if err?
        @emit 'pour', kegerator_id, volume

        # earn a coaster?
        @checkForNewCoasters pour, volume

        ## get the user's info
        @db.findUser pour.rfid, (err, user) =>

          # Tweet about it, whydoncha
          if !err and user? and @kegTwit?
            @db.findKeg pour.keg_id, (err,beer)=>
              @kegTwit.tweetPour user, parseInt(volume, 10), beer
          else if @kegTwit?
            @kegTwit.tweet "Whoa, someone just poured themselves a beer!"
            
          @logger.info "checkin to untappd?"+user.tokens.untappd
          #untappd.userCheckin null, null
          if user.tokens.untappd
            @db.findKeg pour.keg_id, (err,beer)=>
              @untappd.userCheckin user, beer
            

          cb null, true

  # cb = (err, savedToDb)
  # emits 'temp'
  addTemp: (kegerator_id, temp, cb) ->
    kegerator_id = parseInt kegerator_id, 10 if _.isString kegerator_id
    t = new Temperature({temperature: temp, kegerator_id: kegerator_id})
    @db.insertObjects 'temperatures', t, (err, result) =>
      return cb err, false if err?
      @emit 'temp', kegerator_id, temp
      cb null, true

  # cb = (err, savedToDb)
  addUser: (user, cb) ->
    validHex = /^(?:[A-F]|[0-9]){6,12}$/;
    return cb 'invalid RFID', null unless user?.rfid? and validHex.test user.rfid
    @db.insertObjects 'users', user, (err, result) =>
      return cb err, false if err?
      cb null, user
      
  setUserToken:(rfid, token, value, cb)->
    @logger.log rfid + ","+ token+","+ value
    update_str = '{"$set":{"tokens":{"'+ token+ '":"'+value+'" } } }'
    @db.update 'users', {"rfid":rfid}, JSON.parse(update_str), (err, result) ->
      return cb err, false if err?
      cb null, "<html><body>Close this thing<scr" + "ipt>window.close()</scr" + "ipt></body></html>"
    #@db.update 'users', {rfid: user.rfid}, {$set: {coasters: user.coasters}}, () ->

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
          if k.untappd_beer_id > 0
            k = @untappd.getBeer k.untappd_beer_id, (beer)=>
              if beer
                return k = beer
          else
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

async   = require 'async'
moment  = require 'moment'
_       = require 'underscore'
{Db, Server, ReplSetServers} = require 'mongodb'

class DbRebuild

  constructor: () ->
    @dateFormat = 'YYYY-MM-DDTHH:mm:ssZ' #ISO8601

  # cb = (err)
  rebuild: (dbName, server, port, cb) ->
    kegerators = []
    kegerators.push(
        kegerator_id: 2222
        name: 'VNC Seattle'
        description: 'The original home of keg.io'
        owner_email: 'chris.castle@vivaki.com')

    kegerators.push(
        kegerator_id: 1111
        name: 'zulily, Seattle WA'
        description: 'Baby clothes for the win'
        owner_email: 'dcarney@gmail.com')

    kegs = []
    kegs.push(
      keg_id: 1
      kegerator_id: 1111
      beer: "Manny's"
      brewery: 'Georgetown Brewery'
      beer_style: 'Pale Ale'
      description: 'A solid pale ale, brewed in Seattle least-douchey neighborhood.'
      tapped_date: '2011-03-12T01:23:45Z'
      volume_gallons: '15.5'
      active: 'false'
      image_path: 'MannysPint3.gif')

    kegs.push(
      keg_id: 2
      kegerator_id: 2222
      beer: "Immortal"
      brewery: 'Elysian Brewery'
      beer_style: 'IPA'
      description: 'A Northwest interpretation of a classic English style, golden copper in color and loaded with New World hop flavor and aroma.'
      tapped_date: '2011-04-12T01:23:45Z'
      volume_gallons: '15.5'
      active: 'false'
      image_path: 'immortal.jpg')

    users = []
    dc =
      rfid: '44004C234A'
      first_name: 'Dylan'
      last_name: 'Carney'
      nickname: 'Beardo'
      email: 'dcarney@gmail.com'
      twitter_handle:  '@_dcarney_'
      coasters: [1,2]
    users.push dc

    crc =
      rfid: '44004C3A1A'
      first_name: 'Chris'
      last_name: 'Castle'
      nickname: ''
      email: 'crcastle@gmail.com'
      twitter_handle:  '@crc'
      coasters: [1]
    users.push crc

    users.push(
        rfid: '4400561A0A'
        first_name: 'Carl'
        last_name: 'Krauss'
        nickname: ''
        email: 'c4krauss@gmail.com'
        twitter_handle:  '@unstdio'
        coasters: [])

    users.push(
        rfid: '440055F873'
        first_name: 'Garrett'
        last_name: 'Patterson'
        nickname: ''
        email: 'garrett.patterson@vivaki.com'
        twitter_handle:  '@thegarrettp'
        coasters: [])

    pours = []
    pours.push(
        rfid: dc.rfid
        keg_id: 1
        kegerator_id: 1111
        volume_ounces: 16
        date: moment().format(@dateFormat))

    pours.push(
        rfid: crc.rfid
        keg_id: 1
        kegerator_id: 2222
        volume_ounces: 32
        date: moment().format(@dateFormat))

    temps = []
    temps.push(
        temperature: 36
        kegerator_id: 1111
        date: moment().format(@dateFormat))

    temps.push(
        temperature: 37
        kegerator_id: 1111
        date: moment().add('m', 10).format(@dateFormat))

    temps.push(
        temperature: 39
        kegerator_id: 2222
        date: moment().format(@dateFormat))

    temps.push(
        temperature: 40
        kegerator_id: 2222
        date: moment().add('m', 8).format(@dateFormat))

    coasters = []
    coasters.push(
        coaster_id: 1
        name: 'Welcome'
        description: 'Pour a beer with keg.io!'
        image_path: 'coasters/firstbeer.png')

    coasters.push(
        coaster_id: 2
        name: 'Early Bird'
        description: 'Pour a beer before noon.'
        image_path: 'coasters/earlybird.png')

    # cb: (err, result)
    dropDb = (dbName, cb) ->
      console.log "dropping: #{dbName}"
      db = new Db(dbName, new Server(server, port))
      db.open (err, db) ->
        console.log "Err: #{err}" if err?
        return cb err, null if err?
        db.dropDatabase cb

    # cb = (err)
    insertObjects = (collectionName, db, objs, cb) ->
      db.collection collectionName, (err, collection) ->
        return cb err if err?
        console.log "saving objects to: #{collectionName}"
        _.each objs, (obj) -> collection.insert obj
        cb()

    # cb = (err)
    uniqueIndex = (db, collectionName, property, cb) ->
      db.collection collectionName, (err, collection) ->
        return cb err if err?
        console.log "ensuring unique index on: #{collectionName}.#{property}"
        idx = {}
        idx[property] = true
        collection.ensureIndex idx, {unique: true, dropDups: true}, (err, idxName) ->
          return cb err if err?
          cb()

    dropDb dbName, (err, result) ->
      console.log "creating: #{dbName}"
      db = new Db(dbName, new Server(server, port,
        {auto_reconnect: false, poolSize: 4}), {native_parser: false})

      db.open (err, db) ->
        console.log "opened: #{dbName}"
        workers = [
          (cb) -> insertObjects 'kegerators', db, kegerators, cb
          (cb) -> insertObjects 'kegs', db, kegs, cb
          (cb) -> insertObjects 'users', db, users, cb
          (cb) -> insertObjects 'temperatures', db, temps, cb
          (cb) -> insertObjects 'pours', db, pours, cb
          (cb) -> insertObjects 'coasters', db, coasters, cb]
        async.parallel workers, (err, results) ->
          return cb err if err?
          workers = [
            (cb) -> uniqueIndex db, 'kegerators', 'kegerator_id', cb
            (cb) -> uniqueIndex db, 'kegs', 'keg_id', cb
            (cb) -> uniqueIndex db, 'users', 'rfid', cb
            (cb) -> uniqueIndex db, 'coasters', 'coaster_id', cb
          ]
          async.parallel workers, (err, results) ->
            return cb err if err?
            cb()

module.exports = DbRebuild
async   = require 'async'
_       = require 'underscore'

{Server, Db, ReplSetServers, Collection} = require 'mongodb'

class KegDb

  ###
  mongoConfig: an obj containing (at least) the servers to use for the
                connections.  Typically from configuration JSON
  Ex: {
       "db": "kegio",
       "servers": [{"host": "localhost",
                    "port": 27017}]
      }
  ###
  constructor: (@mongoConfig) ->
    @db = null
    @servers = null # single server or repl set

  # cb = (err)
  getServers: () =>
    if @mongoConfig.replSet?
      serverConnections = []
      _.each @mongoConfig.servers, (server) ->
        do (server) ->
          srvr = new Server(server.host, server.port, {auto_reconnect: true})
          serverConnections.push srvr
      new ReplSetServers serverConnections, rs_name: @mongoConfig.replSet, read_secondary: true
    else
      server = @mongoConfig.servers[0]
      new Server(server.host, server.port, {auto_reconnect: true})

  connect: (cb) =>
    @servers = @getServers()
    db = new Db @mongoConfig.db, @servers, {}
    db.open (err, db) =>
      return cb err if err?
      @db = db
      cb()

  # cb = (err, bool)
  exists: (dbName, cb) =>
    db = new Db 'admin', @getServers()
    db.open (err, db) ->
      return cb err, null if err?
      db.admin().listDatabases (err, dbs) ->
        return cb err, null if err?
        cb(null, _.any(dbs.databases, (db) -> db.name == dbName))

  # Performs an insert for each of the given objects into the specified
  # collection
  #
  # cb = (err, null)
  insertObjects: (collectionName, objs, cb) =>
    if (not _.isArray objs) && _.isObject objs
      objs = [objs]
    @db.collection collectionName, (err, collection) ->
      return cb err, null if err?
      _.each objs, (obj) -> collection.insert obj
      cb null, null

  # updates (upserts actually) documents in the given collection,
  # using the provided selector
  #
  # cb = (err, null)
  update: (collectionName, selector, doc, cb) =>
    @db.collection collectionName, (err, collection) ->
      return cb err, null if err?
      collection.update selector, doc, {upsert: true}
      cb null, null

  # cb = (err, entity)
  handleFindOne: (cb, err, entity) ->
    return cb err if err?
    return cb() unless entity?
    cb null, entity

  handleFind: (cb, err, cursor) ->
    return cb err, null if err?
    return cb(null, null) unless cursor?
    cursor.toArray(cb)

  # criteria 1 or more of: {limit: 1, id: 45}
  # cb = (err, kegerators)
  findKegerators: (criteria, cb) =>
    @getCollection 'kegerators', (err, collection) =>
      return cb err, null if err?
      limit = if criteria?.limit? then {limit: criteria.limit} else {}
      selector = if criteria?.id? then {kegerator_id: parseInt(criteria.id, 10)} else {}
      console.log selector
      collection.find selector, limit, (err, cursor) =>
        @handleFind cb, err, cursor

  # cb = (err, keg)
  findKeg: (kegId, cb) =>
    @getCollection 'kegs', (err, collection) =>
      return cb err, null if err?
      collection.findOne {kegId: kegId}, {}, (err, entity) =>
        @handleFindOne cb, err, entity

  # cb = (err, kegs)
  findKegs: (criteria, cb) =>
    @getCollection 'kegs', (err, collection) =>
      return cb err, null if err?
      limit = if criteria?.limit? then {limit: criteria.limit} else {}
      selector = if criteria?.id? then {kegerator_id: parseInt(criteria.id, 10)} else {}
      collection.find selector, limit, (err, cursor) =>
        @handleFind cb, err, cursor

  # cb = (err, temps)
  findTemperatures: (criteria, cb) =>
    @getCollection 'temperatures', (err, collection) =>
      return cb err, null if err?
      limit = if criteria?.limit? then {limit: criteria.limit} else {}
      selector = if criteria?.id? then {kegerator_id: parseInt(criteria.id, 10)} else {}
      collection.find selector, limit, (err, entity) =>
        @handleFind cb, err, entity

  # cb = (err, pours)
  findPours: (criteria, cb) =>
    @getCollection 'pours', (err, collection) =>
      return cb err, null if err?
      limit = if criteria?.limit? then {limit: criteria.limit} else {}
      selector = {}
      if criteria?.id?
        selector = {kegerator_id: parseInt(criteria.id, 10)}
      else if criteria?.rfid?
        selector = {rfid: criteria.rfid}
      collection.find selector, limit, (err, cursor) =>
        @handleFind cb, err, cursor

  # cb = (err, user)
  findUser: (rfid, cb) =>
    @getCollection 'users', (err, collection) =>
      return cb err, null if err?
      collection.findOne {rfid: rfid}, {}, (err, entity) =>
        @handleFindOne cb, err, entity

  # cb = (err, users)
  findUsers: (criteria, cb) =>
    @getCollection 'users', (err, collection) =>
      return cb err, null if err?
      limit = if criteria?.limit? then {limit: criteria.limit} else {}
      selector = {}
      if criteria?.ids? and _.isArray(criteria.ids)
        selector = {rfid: {$in: criteria.ids }}
      else if criteria?.id?
        selector = {rfid: criteria.id}
      collection.find selector, limit, (err, cursor) =>
        @handleFind cb, err, cursor

  # criteria 1 or more of: {limit: 1, id: 45, ids:[45, 13, 2]}
  # cb = (err, coasters)
  findCoasters: (criteria, cb) =>
    @getCollection 'coasters', (err, collection) =>
      return cb err, null if err?
      limit = if criteria?.limit? then {limit: criteria.limit} else {}
      selector = {}
      if criteria?.ids? and _.isArray(criteria.ids)
        selector = {coaster_id: {$in: criteria.ids }}
      else if criteria?.id?
        selector = {coaster_id: parseInt(criteria.id, 10)}
      collection.find selector, limit, (err, cursor) =>
        @handleFind cb, err, cursor

  # cb = (err, collection)
  getCollection: (name, cb) =>
    @db.collection name, (err, collection) ->
      return cb err, null if err?
      cb null, collection

module.exports = KegDb
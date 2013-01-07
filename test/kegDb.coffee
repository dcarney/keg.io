assert = require "assert"
KegDb = require '../lib/kegDb'
{Server, Db, ReplSetServers, Collection} = require 'mongodb'

describe 'KegDb', ->
  singleConfig = {
    "db": "kegio",
    "servers": [{ "host": "test-host", "port": 12345 }]
  }

  multiConfig = {
    "db": "kegio",
    "servers": [{ "host": "test1", "port": 2}, { "host": "test2", "port": 3}]
  }

  it 'should get replicaset', ->
    kegdb = new KegDb(multiConfig)
    s = kegdb.getServers()
    assert.ok(s instanceof ReplSetServers)
    assert.equal(s.servers[0].host, 'test1')
    assert.equal(s.servers[1].host, 'test2')
    
  it 'should get single server', ->
    kegdb = new KegDb(singleConfig)
    server = kegdb.getServers()
    assert.ok(server instanceof Server)
    assert.equal(server.host, 'test-host')
    assert.equal(server.port, 12345)

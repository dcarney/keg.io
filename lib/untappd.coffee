
UntappdClient = require 'node-untappd'

class Untappd
  constructor: (logger, config) ->
    @logger = logger
    @untappd = null
    @untappd = new UntappdClient(config.debug)
    @untappd.setClientId(config.client_id)
    @untappd.setClientSecret(config.client_secret)

  searchUser:(query,cb)->
    @logger.info "verfiy untappd user:"+query
    @untappd.userInfo (err,obj)=>
      @logger.info obj
      if obj and obj.response and obj.response.user
        res = obj.response.user
      else
        res = obj
      @logger.info res
      cb null, res
    ,query
    
  getBeer:(beerid,cb)->
    @logger.info "lookup beerID:"+beerid
    @untappd.beerInfo (err,obj)=>
      if obj.meta and obj.meta.code==200
        cb obj.response.beer
        @logger.info obj.response.beer
      else
        cb null
    , beerid




module.exports = Untappd
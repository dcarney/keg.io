
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




module.exports = Untappd

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
      else
        cb null
    , beerid


  userCheckin:(user,beer) ->
    @logger.info "beer checkin"
    @untappd.setAccessToken(user.tokens.untappd)
    #(callback,gmt_offset,timezone,beer_id,foursquare_id,user_lat,user_long,comment,rating,facebook,twitter,foursqaure,gowalla)
    @untappd.checkin ((err,res)->
      console.log "err:"+err
      console.log res
      console.log "Untappd API Checkin"
    ), -8,"PST",beer.untappd_beer_id,null,null,null,"From http://www.keg.io",null,null,false,false,false

module.exports = Untappd
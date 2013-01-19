
UntappdClient = require 'node-untappd'
moment      = require 'moment'
os          = require 'os'

class Untappd
  constructor: (logger, config) ->
    @logger = logger
    @checkin_delay_hours = config.checkin_delay_hours
    @checkin_comment = config.checkin_comment
    @untappd = null
    @supress = []
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

  getAuthenticationURL: (host, rfid)->
    url = 'http://'+host+'/users/'+rfid+'/untappd'
    return @untappd.getAuthenticationURL(url)
    
  getAuthorizationURL: (host, rfid, code) ->
    url = 'http://'+host+'/users/'+rfid+'/untappd'
    return @untappd.getAuthorizationURL(url,code)

  userCheckin:(user,pour,beer) =>
    @logger.info "beer checkin"
    message = pour.volume_ounces + 'oz pour, from http://www.keg.io'
    comment = "just poured another "+ pour.volume_ounces + "oz..."
    @untappd.setAccessToken(user.tokens.untappd)

    #untappd has a bit of delay and/or caching on thier API for checkins
    #creating a buffer with a minute supression per rfid to prevent multiple
    #subsequent pours from creating mulitple checkins
    #we could build a buffer to store most recent checkin ID locally, potential to be a memory leak.
    
    if @supress.indexOf(user.rfid) > -1
      @logger.warn 'Supressing untappd call'
      return true
    else
      @supress.push user.rfid
      setTimeout ()=>
        @supress.splice @supress.indexOf(user.rfid), 1
      ,60000
    #userFeed = function(callback,lookupUser,limit,offset)
    #(callback,gmt_offset,timezone,beer_id,foursquare_id,user_lat,user_long,comment,rating,facebook,twitter,foursqaure,gowalla)
    @untappd.userFeed ((err,res)=>
      if res.meta.code is 200 
        if res.response.checkins.count > 0 and beer.untappd_beer_id is res.response.checkins.items[0].beer.bid and (moment().diff(moment(res.response.checkins.items[0].created_at),'hours')) <@checkin_delay_hours
          #@logger.info "do untappd comment?" + @checkin_comment
          if @checkin_comment
            @logger.info "untappd comment"
            #that.addComment = function(callback,checkin_id,comment) {
            @untappd.addComment (err,res)=>
              @logger.info "successful checkin comment"
            , res.response.checkins.items[0].checkin_id, comment
        else
          @logger.info "untappd new checkin"
          @untappd.checkin ((err,res)=>
            if res.meta.code is 200
              @logger.info "Untappd API Checkin"
            else
              #TODO: This is PST, should get timezone from kegerator
              @logger.error res.meta.error_detail
          ), -8,"PST",beer.untappd_beer_id,null,null,null,message,null,null,false,false,false
      else
        @logger.error res.meta.error_detail
    ),'',1

module.exports = Untappd
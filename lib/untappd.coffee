
UntappdClient = require 'node-untappd'
moment      = require 'moment'

class Untappd
  constructor: (logger, config) ->
    @logger = logger
    @checkin_delay_hours = config.checkin_delay_hours
    @checkin_comment = config.checkin_comment
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


  userCheckin:(user,pour,beer) =>
    @logger.info "beer checkin"
    message = pour.volume_ounces + 'oz pour, from http://www.keg.io'
    comment = "just poured another "+ pour.volume_ounces + "oz..."
    @untappd.setAccessToken(user.tokens.untappd)
    #userFeed = function(callback,lookupUser,limit,offset)
    #(callback,gmt_offset,timezone,beer_id,foursquare_id,user_lat,user_long,comment,rating,facebook,twitter,foursqaure,gowalla)
    @untappd.userFeed ((err,res)=>
      if res.meta.code is 200
        console.log "user response:"
        console.log "res.response.checkins.count:" + res.response.checkins.count
        console.log "first checkin:" + res.response.checkins.items[0]
        console.log "checkin beer id:" + res.response.checkins.items[0].beer.bid
        console.log "current beer:" + beer.untappd_beer_id
        console.log "now:" + moment()
        console.log "checkin:"+ res.response.checkins.items[0].created_at + "," + moment(res.response.checkins.items[0].created_at)
        console.log (moment(res.response.checkins.items[0].created_at).diff(moment(),'hours'))
        console.log moment().diff(moment(res.response.checkins.items[0].created_at),'hours') + ">?" +  @checkin_delay_hours 
        #return
        if res.response.checkins.count > 0 and beer.untappd_beer_id is res.response.checkins.items[0].beer.bid and (moment().diff(moment(res.response.checkins.items[0].created_at),'hours')) <@checkin_delay_hours
          console.log "do untappd comment?" + @checkin_comment
          if @checkin_comment
            console.log "untappd comment"
            #that.addComment = function(callback,checkin_id,comment) {
            @untappd.addComment (err,res)=>
              console.log "successful checkin comment"
            , res.response.checkins.items[0].checkin_id, comment
        else
          console.log "new"
          @untappd.checkin ((err,res)->
            console.log "err:"+err
            console.log res
            console.log "Untappd API Checkin"
          ), -8,"PST",beer.untappd_beer_id,null,null,null,message,null,null,false,false,false

    ),'',1

module.exports = Untappd
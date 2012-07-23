moment = require 'moment'
#
# Pour: A beer dispensing event for a User on a Keg
#
class Pour

  constructor: (db_obj) ->
    {@rfid, @keg_id, @kegerator_id, @volume_ounces, @rates, @date} = db_obj
    @dateFormat = 'YYYY-MM-DDTHH:mm:ssZ' #ISO8601

  addFlow: (rate) ->
    @rates ||= []
    @rates.push {rate: rate, time: new Date()}

  calculateVolume: () ->
    @date = moment().format(@dateFormat)
    @rates.push {rate: 'end', time: new Date()} # assume the pour ends right now
    # TODO: Don't throw away the first rate number by having a time diff of 0
    @volume_ounces = 0.0
    last_rate_time = null
    for rate_time in @rates
      # 1 liter per minute = 0.000563567045 US fluid ounces per ms
      # 1 liter per hour = 0.00000939278408 US fluid ounces per ms
      if last_rate_time?
        diff_ms = parseFloat(rate_time.time - last_rate_time.time)
        flow_amount_oz = diff_ms * (parseFloat(last_rate_time.rate) * 0.00000939278408)
        @volume_ounces += flow_amount_oz;
      last_rate_time = rate_time
    @volume_ounces = Math.round @volume_ounces
    @volume_ounces

module.exports = Pour
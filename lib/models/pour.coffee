moment = require 'moment'
#
# Pour: A beer dispensing event for a User on a Keg
#
class Pour

  constructor: (db_obj) ->
    {@rfid, @keg_id, @kegerator_id, @volume_ounces, @rates, @date} = db_obj

module.exports = Pour
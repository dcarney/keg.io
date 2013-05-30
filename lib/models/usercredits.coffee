#
# UserCredits storage for credits by user/keg
#
class UserCredits

  constructor: (db_obj) ->
    {@kegerator_id,
     @rfid
     @ounces
     @expiration_date
     @created_date} = db_obj

module.exports = Keg
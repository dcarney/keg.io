#
# Kegerator: A location running the keg.io client software. A physical device
#            that contains Keg(s)
#
class Kegerator

  constructor: (db_obj) ->
    {@access_key, @name, @description, @owner_email} = db_obj

module.exports = Kegerator
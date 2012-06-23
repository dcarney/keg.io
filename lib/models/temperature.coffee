#
# Temperature: a temp reading for a given Kegerator
#
class Temperature
  constructor: (db_obj) ->
    {@kegerator_id, @temperature, @date} = db_obj

module.exports = Temperature
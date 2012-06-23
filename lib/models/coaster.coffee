#
# Coaster: An achievement/badge earned by a user
#
class Coaster

  constructor: (db_obj) ->
    {@coaster_id, @name, @description, @image_path, @image_path} = db_obj

module.exports = Coaster
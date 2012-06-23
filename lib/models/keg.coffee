#
# Keg: a physical keg of beer.
#
class Keg

  constructor: (db_obj) ->
    {@kegerator_id,
     @beer
     @brewery
     @beer_style
     @description
     @tapped_date
     @volume_gallons
     @active
     @image_path} = db_obj

module.exports = Keg
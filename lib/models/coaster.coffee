###
#
# Coaster: An achievement/badge earned by a user
#
#
#  Current Coasters:
#    - 1: Welcome (has poured a beer with keg.io); multiple people
#    - 2: Early bird (pour before a certain hour of day); multiple people
#    - 3: Mayor/duke/king/etc (top drinker overall); single person
#    - 4: Keg mayor/duke/king/etc (top drinker of a keg); multiple people
#    - 5: Party starter (has poured the first beer of the day); multiple people
#    - 6: Closer (has poured the last beer of the day); multiple people
#    - 7: Off the wagon (resumed pouring after a prolonged absence); multiple people
#    - 8: Take the bus home (has poured above a certain ounces/hour): multiple people
###
class Coaster
  [@WELCOME, @EARLY_BIRD, @PARTY_STARTER, @OFF_THE_WAGON, @TAKE_THE_BUS_HOME ] = [1,2,5,7,8]

  constructor: (db_obj) ->
    {@coaster_id, @name, @description, @image_path, @image_path} = db_obj

module.exports = Coaster
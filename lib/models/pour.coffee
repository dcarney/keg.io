#
# Pour: A beer dispensing event for a User on a Keg
#
module.exports = (sequelize, DataTypes) ->
  sequelize.define('pour', {
    rfid: DataTypes.INTEGER,
    pour_date: DataTypes.DATE,
    volume_ounces: DataTypes.INTEGER
  }, {underscored: true})
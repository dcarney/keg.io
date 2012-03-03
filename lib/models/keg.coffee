#
# Keg: a physical keg of beer
#
module.exports = (sequelize, DataTypes) ->
  sequelize.define('keg', {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true, unique: true},
    beer: DataTypes.STRING,
    brewery: DataTypes.STRING,
    beer_style: DataTypes.STRING,
    description: DataTypes.TEXT,
    tapped_date: DataTypes.DATE,
    volume_gallons: {type: DataTypes.STRING, validate: {isFloat: true}},
    active: DataTypes.BOOLEAN,
    image_path: DataTypes.STRING
  },
  { underscored: true })

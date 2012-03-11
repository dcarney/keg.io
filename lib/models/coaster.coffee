#
# Coaster: A 'badge' or 'acheivement' (think foursquare)
#
module.exports = (sequelize, DataTypes) ->
  sequelize.define('coaster', {
    name: DataTypes.STRING,
    description: DataTypes.TEXT,
    image_path: DataTypes.TEXT
  },
  {
    underscored: true,
    timestamps: false
  })
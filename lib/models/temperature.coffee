#
# Temperature: a temp reading for a given Kegerator
#
module.exports = (sequelize, DataTypes) ->
  sequelize.define('temperature', {
    kegerator_id: DataTypes.INTEGER,
    temperature: DataTypes.INTEGER
  }, {underscored: true})
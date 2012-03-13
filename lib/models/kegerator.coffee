#
# Kegerator: a physical device that contains Keg(s)
#
module.exports = (sequelize, DataTypes) ->
  sequelize.define('kegerator', {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true, unique: true},
    access_key: {type: DataTypes.STRING, unique: true},
    name: DataTypes.STRING,
    description: DataTypes.TEXT,
    owner_email: DataTypes.STRING
  }, {underscored: true})
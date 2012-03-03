crypto      = require 'crypto'

#
# User: a drinker of beer
#
module.exports = (sequelize, DataTypes) ->
  sequelize.define('user', {
    rfid: { type: DataTypes.STRING, unique: true},
    first_name: DataTypes.STRING,
    last_name: DataTypes.STRING,
    nickname: DataTypes.STRING,
    email: {type: DataTypes.STRING, validate: {isEmail: true}},
    twitter_handle: DataTypes.STRING
    },
    {
      underscored: true,
      instanceMethods: {
        # gets a name appropriate for displaying on Twitter: if the user has no
        # Twitter handle, a combination of name and nickname is used
        getTwitterName: () ->
          name = @first_name
          name = "#{@first_name} " +
              (if (@nickname? && @nickname.length > 0) then "'#{@nickname}' " else "") +
              @last_name

          # Use the twitter handle instead, if the user has one.
          if @twitter_handle? && @twitter_handle.length > 0
            # Add the '@' symbol to the twitter handle to properly "mention" the user
            # Add the . so we mention instead of DM
            prefix = if @twitter_handle.indexOf('@') != -1 then '.' else '.@'
            name =  "#{prefix}#{@twitter_handle}"

          name

        emailHash: (cb) ->
          md5Hash = ''
          if @email? && @email.length > 0
            md5Hash = crypto.createHash('md5').update(@email).digest("hex")
          cb md5Hash

      }
    })
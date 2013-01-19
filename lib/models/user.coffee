crypto      = require 'crypto'

#
# User: a drinker of beer
#
class User
  constructor: (db_obj) ->
    {@rfid, @first_name, @last_name, @nickname, @email, @twitter_handle, @coasters, @tokens} = db_obj

  # gets a name appropriate for displaying on Twitter: if the user has no
  # Twitter handle, a combination of name and nickname is used
  getTwitterName: () =>
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

  # Gets the URL of a gravatar image for the user.  This isn't persisted to
  # the DB, so that the URL can reflect changes to the user's email
  #
  # cb = (gravatar_url)
  getGravatar: (cb) =>
    return cb '' unless @email? && @email.length > 0
    md5hash = crypto.createHash('md5').update(@email).digest("hex")
    cb "http://www.gravatar.com/avatar/#{md5hash}?s=256"

module.exports = User

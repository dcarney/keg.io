sys     = require 'util'
twitter = require 'ntwitter'

class KegTwitter
  constructor: (logger, config) ->
    @logger = logger
    @twit = null
    @lastTempTweetDate = null
    @twit = new twitter({
      consumer_key: config.consumer_key,
      consumer_secret: config.consumer_secret,
      access_token_key: config.access_token_key,
      access_token_secret: config.access_token_secret})

  # Sends a tweet, using 'message' as the tweet body.  If the 'message' param
  # is too long (e.g. > 140 characters), it will be truncated and an ellipsis
  # (...) will be appended.
  tweet: (message) ->
    if message? && message.length > 140
      message = message.substring(0, 136) + "..."

    if @logger?
      @logger.info "Tweeting the message:'#{message}'."

    if @twit
      @twit.post '/statuses/update.json', { status: message }, (data) =>
        @logger.trace sys.inspect(data)

  getTwitterName: (userInfo) ->
    # Use the person's regular name (including any given nickname)
    # Ex. Dylan 'Beardo' Carney
    name = "#{userInfo.first_name} " +
          (if (userInfo.nickname? && userInfo.nickname.length > 0) then "'#{userInfo.nickname}' " else "") +
          userInfo.last_name

    # Use the twitter handle instead, if the user has one.
    if userInfo.twitter_handle? && userInfo.twitter_handle.length > 0
      # Add the '@' symbol to the twitter handle to properly "mention" the user
      # Add the . so we mention instead of DM
      prefix = if userInfo.twitter_handle.indexOf('@') != -1 then '.' else '.@'
      name =  "#{prefix}#{userInfo.twitter_handle}"

    name

  isTweetLength: (message) ->
    message? && message.length <= 140

  tweetTemp: (currentTemp) ->
    # Don't tweet this more than once per hour
    if (@lastTempTweetDate == null ||
        (new Date()).getTime() - this.lastTempTweetDate.getTime() >= 3600000) # 3600000 ms = 1 hour
      @lastTempTweetDate = new Date()
      @tweet "Whoa! This beer is getting too warm! It's currently #{currentTemp} degrees!"

  tweetPour: (userInfo, ounces, beerInfo) =>
    name = @getTwitterName userInfo

    pouredText = " just poured #{ounces} oz of "
    longBeerText = "tasty #{beerInfo.beer} #{beerInfo.beer_style}"
    shortBeerText = 'tasty, tasty beer'
    shortShortBeerText = 'tasty beer'

    if @isTweetLength(name + pouredText + longBeerText)
      @tweet(name + pouredText + longBeerText)
    else if @isTweetLength(name + pouredText + shortBeerText)
      @tweet(name + pouredText + shortBeerText)
    else if @isTweetLength(name + pouredText + shortShortBeerText)
      @tweet(name + pouredText + shortShortBeerText)

  tweetCoaster: (userInfo, coasterInfo) ->
    name = getTwitterName userInfo
    earnedText = " just earned the '#{coasterInfo[0].name}' coaster!"

    if @isTweetLength(name + earnedText)
      @tweet(name + earnedText)

module.exports = KegTwitter
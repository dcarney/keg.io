signer = require 'string-signer' # used to sign each HTTP request
url = require 'url'
sys = require 'util'
payload    = require './payload'
moment = require 'moment'

heartbeats = {}

# remove extraneous headers, to save on arduino reading/processing
module.exports.removeHeaders = () ->
  (req, res, next) ->
    res.removeHeader 'X-Powered-By'
    res.removeHeader 'Content-Type'
    next()

# verify the request's signature, based on our signing scheme and a secret key
module.exports.verify = (keys = {}) ->
  (req, res, next) ->
      try
        throw Error('Request must must be signed') unless req.query? && req.query.signature?
        throw Error('Request is missing an accessKey') unless req.accessKey?
        secret = keys[req.accessKey]
        throw Error("Unknown accessKey: #{req.accessKey}") unless secret?
        to_sign = payload.getRequestPayload req
        # console.log to_sign
        valid = signer.isValidSignature(req.query.signature, to_sign, secret)
        throw Error('Invalid request signature') unless valid
        next()
      catch err
        # return a 400, (leaving off any "extraneous" headers)
        # with the appropriate message
        res.writeHead 400
        res.end err.message

# set a 'path' property on the req object (used by verify())
module.exports.path = () ->
  (req, res, next) ->
    req.path = url.parse(req.url).pathname
    next()

# set an 'accessKey' property on the req object (used by verify())
# Ex. For request: http://keg.io/api/kegerator/1111/flow/13
#     the access key is '1111'
module.exports.accessKey = () ->
  (req, res, next) ->
    match = /\/kegerator\/([0-9]+)\//i.exec(req.url)
    req.accessKey = match[1] if match
    next()

# record the time that an arduino client was last heard from
module.exports.captureHeartbeat = () ->
  (req, res, next) ->
    throw Error('Request is missing an accessKey') unless req.accessKey?
    heartbeats[req.accessKey] = moment()
    next()

# not strictly a middleware, but an accessor for getting the heartbeats obj
module.exports.getHeartbeats = () ->
  return heartbeats

signedRequest = require 'signed-request' # used to sign each HTTP request
url = require 'url'

# verify the request's signature, based on our signing scheme and a secret key
module.exports.verify = (keys = {}) ->
  (req, res, next) ->
    if req.query? && req.query.signature? # onluy check requests with a sig
      try
        throw Error('Request is missing an accessKey') unless req.accessKey?
        secret = keys[req.accessKey]
        throw Error("Unknown accessKey: #{req.accessKey}") unless secret?
        path = if req.path? then req.path.toLowerCase() else ''
        to_sign = "#{req.method.toUpperCase()} http://#{req.headers.host}#{path}"
        valid = signedRequest.isValidSignature(req.query.signature, to_sign, SECRET)
        throw Error('Invalid request signature') unless valid
        next()
      catch err
        console.log err.message
        # return a 400, with the appropriate message
        res.writeHead(400, {'Content-Type': 'text/plain'})
        res.end(err.message)
    else
      next()

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
    console.log "ACCEESSSSSSKEY!!!!"
    match = /\/api\/kegerator\/([0-9]+)\//i.exec(req.url)
    req.accessKey = match[1] if match
    next()
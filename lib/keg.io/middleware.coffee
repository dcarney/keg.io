signedRequest = require 'signed-request' # used to sign each HTTP request
url = require 'url'

# verify the request's signature, based on our signing scheme and a secret key
module.exports.verify = () ->
  (req, res, next) ->
    SECRET = 's3cr3t'
    if req.query? && req.query.signature?
      path = if req.path? then req.path.toLowerCase() else ''
      to_sign = "#{req.method.toUpperCase()} http://#{req.headers.host}#{path}"
      valid = signedRequest.isValidSignature(req.query.signature, to_sign, SECRET)
      unless valid
        console.log 'INVALID REQUEST SIGNATURE!'
        res.writeHead(400, {'Content-Type': 'text/plain'})
        res.end("Incorrect request signature")
      next()
    else
      next()

# set a 'path' property on the req object (used by verify())
module.exports.path = () ->
  (req, res, next) ->
    req.path = url.parse(req.url).pathname
    next()
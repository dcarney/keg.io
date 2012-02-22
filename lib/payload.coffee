genPayload = (method, host, path, data) ->
  payload = "#{method.toUpperCase()} #{host.toLowerCase()}"
  payload += (if path? then path else '').toLowerCase()
  payload += (if data? && data != '' then "?#{data}" else '').toLowerCase()

# Convenince method for generating a payload from one of our reqest objects
# (typically a
# [node.js http.ServerRequest](http://nodejs.org/docs/v0.6.3/api/http.html#http.ServerRequest)
# object with a few extra properties appended)
module.exports.getRequestPayload = (req) ->
  genPayload(req.method, req.headers.host, req.path, req.data)

# Generate a payload for signing by using the following HTTP parameters:
#  - method (GET, PUT, etc.)
#  - host (keg.io, localhost:8080, etc.)
#  - path (/api/kegerator/1111/flow/23, /images/foobar.png, etc.)
#  - data
module.exports.getPayload = (method, host, path, data) ->
  genPayload(method, host, path, data)
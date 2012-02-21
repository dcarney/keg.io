module.exports = verify = () ->
  (req, res, next) ->
    console.log 'YYYYEEEPPPPP'
    #console.log req
    if req.query? && req.query.sig?
      console.log req.query.sig
      if req.query.sig == '666777'
        res.writeHead(400, {'Content-Type': 'text/plain'})
        res.end("Incorrect request signature")
      else
        next()
    else
      next()
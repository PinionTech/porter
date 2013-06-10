upnode = require 'upnode'
portfinder = require 'portfinder'
PORT = 7003
SECRET = process.env.PORTER_PASS ? 'o87asdoa87sa'
authed =
  port: (cb) ->
    portfinder.getPort cb
server = upnode (client, conn) ->
  @auth = (secret, cb) ->
    return cb null, authed if secret == SECRET
    cb 'DENIED'
server.listen(PORT)
console.log "Server listening on #{PORT}"
module.exports =
  authed: authed

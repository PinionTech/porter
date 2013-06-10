upnode = require 'upnode'
portfinder = require 'portfinder'
net = require 'net'
PORT = 7003
SECRET = process.env.PORTER_PASS ? 'o87asdoa87sa'
authed =
  port: (cb) ->
    portfinder.getPort cb
server = upnode (client, conn) ->
  @auth = (secret, cb) ->
    return cb null, authed if secret == SECRET
    cb 'DENIED'
checkPort = ->
  tester = net.createServer()
  tester.on 'error', (error) ->
    console.log "Porter already running?"
    setTimeout ->
      checkPort()
    , 10 * 60 * 1000
  tester.listen PORT, ->
    tester.close ->
      server.listen PORT
checkPort()
console.log "Server listening on #{PORT}"
module.exports =
  authed: authed

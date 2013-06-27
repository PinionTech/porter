upnode = require 'upnode'
portfinder = require 'portfinder'
net = require 'net'
http = require 'http'
router = require './lib/router'
PORT = 7004
SECRET = process.env.PORTER_PASS ? 'o87asdoa87sa'

butler =
  host: process.env.BUTLER_HOST
  port: process.env.BUTLER_PORT
  secret: process.env.BUTLER_SECRET
droneName = process.env.DRONE_NAME

checkin = (remote) ->
  return if process.env.PORTER_TESTING
  opts =
    hostname: remote.host
    port: remote.port
    path: "/checkin/#{droneName}"
    auth: "porter:#{remote.secret}"
  connection = http.get opts, (res) ->
    throw new Error "Checkin failed with status #{res.statusCode}" if res.statusCode != 200
    console.log "Checked in with #{remote.host}:#{remote.port}"
    @socket.end()
  .on "error", (e) ->
    throw new Error e

  connection.on 'socket', (socket) ->
    socket.setTimeout(10 * 1000)
    socket.on 'timeout', ->
      throw new Error "Checkin timeout"

listen = ->
  server.listen PORT
  checkin(butler)
  setInterval ->
    checkin(butler)
  , 60 * 1000

authed =
  port: (cb) ->
    portfinder.getPort (err, port) ->
      portfinder.basePort = port + 1
      cb err, port
  updateRouting: (routes, cb) ->
    router.writeFile routes, cb

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
    , 10 * 1000
  tester.listen PORT, ->
    tester.close ->
      listen()

checkPort()

console.log "Server listening on #{PORT}"

module.exports =
  authed: authed

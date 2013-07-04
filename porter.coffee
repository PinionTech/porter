upnode = require 'upnode'
portfinder = require 'portfinder'
net = require 'net'
http = require 'http'
path = require 'path'
spawn = require('child_process').spawn
router = require './lib/router'
PORT = 7004
SECRET = process.env.PORTER_PASS ? 'o87asdoa87sa'

nginx = null

cleanup = (err) ->
  nginx.kill() if nginx?
  throw err

butler =
  host: process.env.BUTLER_HOST
  port: process.env.BUTLER_PORT
  secret: process.env.BUTLER_SECRET
droneName = process.env.DRONE_NAME

spawnNginx = ->
  nginx = spawn "nginx", ['-c', path.resolve(__dirname, 'nginx', 'nginx.conf')]

  nginx.stdout.on 'data', (data) ->
    console.log "Stdout from nginx:", data.toString()
  nginx.stderr.on 'data', (data) ->
    console.error "Stderr from nginx", data.toString()
  nginx.on 'close', (code, signal) ->
    console.log "nginx closed with code #{code} and signal #{signal}"
    spawnNginx()

router.writeFile {}, (err) ->
  throw err if err?
  spawnNginx()

getRoutingTable = (remote) ->
  return if process.env.PORTER_TESTING
  opts =
    hostname: remote.host
    port: remote.port
    path: "/routingTable"
    auth: "porter:#{remote.secret}"
  connection = http.get opts, (res) ->
    cleanup new Error "Failed to get routing table, status: #{res.statusCode}" if res.statusCode isnt 200
    responseText = ''
    res.on 'data', (data) ->
      responseText += data.toString()
    res.on 'end', ->
      routingTable = JSON.parse responseText
      router.writeFile routingTable, (err) ->
        cleanup err if err?
      @socket.end()
  .on "error", (e) ->
    cleanup new Error e

checkin = (remote) ->
  return if process.env.PORTER_TESTING
  opts =
    hostname: remote.host
    port: remote.port
    path: "/checkin/#{droneName}"
    auth: "porter:#{remote.secret}"
  connection = http.get opts, (res) ->
    cleanup new Error "Checkin failed with status #{res.statusCode}" if res.statusCode != 200
    console.log "Checked in with #{remote.host}:#{remote.port}"
    @socket.end()
  .on "error", (e) ->
    cleanup new Error e

  connection.on 'socket', (socket) ->
    socket.setTimeout(10 * 1000)
    socket.on 'timeout', ->
      cleanup new Error "Checkin timeout"

listen = ->
  server.listen PORT
  checkin(butler)
  getRoutingTable(butler)
  setInterval ->
    checkin(butler)
  , 60 * 1000

authed =
  port: (cb) ->
    portfinder.getPort (err, port) ->
      portfinder.basePort = port + 1
      portfinder.basePort = 8000 if portfinder.basePort > 9000
      cb err, port
  updateRouting: (routes, cb) ->
    router.writeFile routes, (err) ->
      #kill is a misnomer, this instructs nginx to re-read it's configuration and gracefully retire it's workers. http://nginx.org/en/docs/control.html
      nginx.kill 'SIGHUP' unless err?
      cb err

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

assert = require 'assert'
upnode = require 'upnode'
net = require 'net'
spawn = require('child_process').spawn
SECRET = 'o87asdoa87sa'
process.env.PORTER_TESTING = true
describe 'auth', ->
  porter = null
  before () ->
    porter = spawn 'node', ['../porter.js']
    porter.on 'error', (err) ->
      throw new Error err
  after () ->
    porter.kill()
  it 'should fail without a password', (done) ->
    up = upnode.connect '7004', (remote, conn) ->
      try
        remote.port (err, res) ->
          console.log err, res
      catch error
        return done() if error instanceof Error
  it 'should auth correctly given a password', (done) ->
    up = upnode.connect '7004', (remote, conn) ->
      remote.auth SECRET, (err, res) ->
        assert.equal err, null
        conn.emit 'up', res
    up (remote) ->
      remote.port (err, res) ->
        assert.equal err, null
        done()
describe 'freeport', ->
  porter = require '../porter.coffee'
  it 'should return a numeric port', ->
    porter.authed.port (err, port) ->
      assert.equal err, null
      assert typeof port is 'number'
  it 'should return a port that\'s actually free', (done) ->
    porter.authed.port (err, port) ->
      tester = net.createServer()
      tester.on 'error', (error) ->
        throw new Error error
      tester.listen port, ->
        done()
  it "shouldn't get the same port twice", ->
    porter.authed.port (err, port1) ->
      porter.authed.port (err, port2) ->
        assert.notEqual port1, port2

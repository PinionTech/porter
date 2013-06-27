{exec} = require 'child_process'

build = (callback) ->
  exec "coffee --compile porter.coffee && coffee --compile ./lib/*.coffee", (err, stdout, stderr) ->
    throw new Error(err) if err
    callback() if callback

task 'build', 'Build lib from src', -> build()

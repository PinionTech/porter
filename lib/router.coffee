NginxConfFile = require('nginx-conf').NginxConfFile
path = require 'path'
os = require 'os'

writeFile = (routingTable, cb) ->
  nginxPath = path.resolve 'nginx'
  console.log "writeFile called, nginxPath is", nginxPath
  console.log "nginx.conf is at", path.join(nginxPath, 'nginx.conf')
  NginxConfFile.create path.join(nginxPath, 'nginx.conf'), (err, conf) ->
    console.log "err is", err
    #set system variables
    conf.nginx._remove 'worker_processes'
    conf.nginx._add 'worker_processes', os.cpus().length

    conf.nginx._remove 'pid'
    conf.nginx._add 'pid', path.join(nginxPath, 'nginx.pid')

    conf.nginx.http._remove 'access_log'
    conf.nginx.http._add 'access_log', "#{path.join(nginxPath, 'access.log')} main"

    conf.nginx.http._remove 'error_log'
    conf.nginx.http._add 'error_log', "#{path.join(nginxPath, 'access.log')} debug"

    #burn down all existing servers
    if conf.nginx.http.server?
      if conf.nginx.http.server.length?
        conf.nginx.http._remove('server') for server in conf.nginx.http.server
      else
        conf.nginx.http._remove('server')

    if conf.nginx.http.upstream?
      if conf.nginx.http.upstream.length?
        conf.nginx.http._remove('upstream') for server in conf.nginx.http.server
      else
        conf.nginx.http._remove('upstream')

    for name, data of routingTable

      #add the upstream routing
      conf.nginx.http._add "upstream", name

      #get the right handle to the new upstream
      if conf.nginx.http.upstream.length?
        upstream = conf.nginx.http.upstream[conf.nginx.http.upstream.length - 1]
      else
        upstream = conf.nginx.http.upstream

      upstream._add data.method ? "least_conn"
      for route in data.routes
        upstream._add "server", "#{route.host}:#{route.port}"

      #add the server definition
      conf.nginx.http._add "server"

      if conf.nginx.http.server.length?
        server = conf.nginx.http.server[conf.nginx.http.server.length - 1]
      else
        server = conf.nginx.http.server

      server._add "listen", "7005"
      server._add "server_name", data.domain
      server._add "location", "/"
      server.location._add "proxy_pass", "http://#{name}"

    conf.on 'flushed', ->
      console.log "Flushed!"
      cb null
    console.log "Finished generating file, about to flush"
    conf.flush()
module.exports =
  writeFile: writeFile

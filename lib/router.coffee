NginxConfFile = require('nginx-conf').NginxConfFile
path = require 'path'
os = require 'os'
fs = require 'fs'

writeFile = (routingTable, cb) ->
  nginxPath = path.resolve 'nginx'
  NginxConfFile.create path.join(nginxPath, 'nginx.conf'), (err, conf) ->

    if err?
      console.error "nginx configuration error", err
      template = fs.createReadStream path.join nginxPath, 'template.nginx.conf'
      configFile = fs.createWriteStream path.join nginxPath, 'nginx.conf'
      template.pipe configFile
      cb err

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

    conf.flush()
    cb null
module.exports =
  writeFile: writeFile

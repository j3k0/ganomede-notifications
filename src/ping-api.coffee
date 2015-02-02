ping = (req, res, next) ->
  res.send "pong/" + req.params.token
  next()

addRoutes = (prefix, server) ->
  server.get "/#{prefix}/ping/:token", ping
  server.head "/#{prefix}/ping/:token", ping

module.exports =
  addRoutes: addRoutes

# vim: ts=2:sw=2:et:

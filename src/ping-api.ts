const ping = function(req, res, next) {
  res.send("pong/" + req.params.token);
  next();
};

const addRoutes = function(prefix, server) {
  server.get(`/${prefix}/ping/:token`, ping);
  server.head(`/${prefix}/ping/:token`, ping);
};

export default {addRoutes};

// vim: ts=2:sw=2:et:

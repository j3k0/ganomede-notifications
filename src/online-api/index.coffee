redis = require 'redis'
OnlineList = require './online-list'
config = require '../../config'
log = require '../log'

module.exports = (options={}) ->
  onlineList = options.onlineList

  if !onlineList
    client = redis.createClient(
      config.onlineList.redisPort,
      config.onlineList.redisHost
    )

    onlineList = new OnlineList(client, {maxSize: config.onlineList.maxSize})

  # Return list of usernames most recently online
  onlineListEndpoint = (req, res, next) ->
    onlineList.get (err, list) ->
      if (err)
        log.error('onlineListEndpoint() failed', {err: err})
        restErr = new restify.InternalServerError()
        log.error(restErr)
        return next(restErr)

      res.json(list)
      next()

  api = (prefix, server) ->
    server.get("/#{prefix}/online", onlineListEndpoint)

  api.updateOnlineListMiddleware = (req, res, next) ->
    onlineList.add req.params.user.username, (err) ->
      if (err)
        log.error('updateOnlineListMiddleware() failed', {err: err})

    next()

  return api

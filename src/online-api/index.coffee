redis = require 'redis'
OnlineList = require './online-list'
config = require '../../config'
log = require '../log'

createApi = (options={}) ->
  onlineList = options.onlineList

  if !onlineList
    client = redis.createClient(
      config.onlineList.redisPort,
      config.onlineList.redisHost,
        no_ready_check: true
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

  # Some players should stay invisible
  invisibleMatch = options.invisibleMatch ||
    process.env.ONLINE_LIST_INVISIBLE_MATCH
  isInvisible = options.isInvisible
  if !isInvisible
    if invisibleMatch
      isInvisible = (username) ->
        username.match(invisibleMatch)
    else
      isInvisible = -> false

  api = {}
  
  api.addRoutes = (prefix, server) ->
    server.get("/#{prefix}/online", onlineListEndpoint)

  # Update the list of online players
  api.updateOnlineListMiddleware = (req, res, next) ->
    username = req.params?.user?.username
    if username and !isInvisible username
      onlineList.add username
    next()

  return api

module.exports =
  createApi: createApi

# vim: ts=2:sw=2:et:

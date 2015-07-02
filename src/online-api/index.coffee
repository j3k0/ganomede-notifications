redis = require 'redis'
authdb = require "authdb"
OnlineList = require './online-list'
config = require '../../config'
log = require('../log').child(module: "online-api")
restify = require "restify"

sendError = (err, next) ->
  log.error err
  next err

createApi = (options={}) ->
  onlineList = options.onlineList

  # configure authdb client
  authdbClient = options.authdbClient || authdb.createClient(
    host: config.authdb.host
    port: config.authdb.port)

  if !onlineList
    client = redis.createClient(
      config.onlineList.redisPort,
      config.onlineList.redisHost,
        no_ready_check: true
    )

    onlineList = new OnlineList(client, {maxSize: config.onlineList.maxSize})

  #
  # Middlewares
  #

  # Populates req.params.user with value returned from authDb.getAccount()
  authMiddleware = (req, res, next) ->
    authToken = req.params.authToken
    if !authToken
      return sendError(new restify.InvalidContentError('invalid content'), next)

    authdbClient.getAccount authToken, (err, account) ->
      if err || !account
        return sendError(new restify.UnauthorizedError('not authorized'), next)

      req.params.user = account
      next()

  # Update the list of online players
  updateOnlineListMiddleware = (req, res, next) ->
    username = req.params?.user?.username
    email = req.params?.user?.email
    if username and email and !isInvisible email
      onlineList.add username
    next()

  #
  # Utils
  #

  # Some players should stay invisible
  invisibleMatch = options.invisibleMatch ||
    process.env.ONLINE_LIST_INVISIBLE_MATCH
  isInvisible = options.isInvisible
  if !isInvisible
    if invisibleMatch
      isInvisible = (email) ->
        email.match(invisibleMatch)
    else
      isInvisible = -> false

  #
  # Endpoints
  #

  # Return list of usernames most recently online
  getOnlineList = (req, res, next) ->
    onlineList.get (err, list) ->
      if (err)
        log.error('onlineListEndpoint() failed', {err: err})
        restErr = new restify.InternalServerError()
        log.error(restErr)
        return next(restErr)

      res.json(list)
      next()

  # Update the list of online players
  postOnline = (req, res, next) ->
    res.json ok:true
    next()

  api = {}
  
  api.addRoutes = (prefix, server) ->
    server.get("/#{prefix}/online", getOnlineList)
    server.post("/#{prefix}/auth/:authToken/online",
      authMiddleware, updateOnlineListMiddleware, postOnline)

  # Export the updateOnlineList middleware
  api.updateOnlineListMiddleware = updateOnlineListMiddleware

  return api

module.exports =
  createApi: createApi

# vim: ts=2:sw=2:et:

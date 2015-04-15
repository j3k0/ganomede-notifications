log = require "../log"
authdb = require "authdb"
redis = require "redis"
restify = require "restify"
config = require '../../config'
PubSub = require './pubsub'
Queue = require './queue'
LongPoll = require './long-poll'

sendError = (err, next) ->
  log.error err
  next err

notificationsApi = (options={}) ->
  #
  # Init
  #

  # configure authdb client
  authdbClient = options.authdbClient || authdb.createClient(
    host: config.authdb.host
    port: config.authdb.port)

  # notificatinos redis pub/sub
  # notifications redis queue
  pubsub = options.pubsub
  queue = options.queue

  do () ->
    client = redis.createClient(config.redis.port, config.redis.host)

    if !pubsub
      pubsub = new PubSub
        publisher: client
        subscriber: redis.createClient(config.redis.port, config.redis.host)
        channel: config.redis.channel

    if !queue
      queue = new Queue(client, {maxSize: config.redis.queueSize})

  # notify the listeners of incoming messages
  # called when new data is available for a user
  pubsub.subscribe (channel, username) ->
    # if there's a listener, trigger it
    longPoll.trigger(username)

  longPoll = options.longPoll || new LongPoll(config.longPollDurationMillis)

  # configure the testuser authentication token (to help with manual testing)
  if process.env.TESTUSER_AUTH_TOKEN
    authdbClient.addAccount process.env.TESTUSER_AUTH_TOKEN,
      username: "testuser"
      email: "testuser@fovea.cc"
      , (err, result) ->

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

  # Check the API secret key validity
  apiSecretMiddleware = (req, res, next) ->
    secret = req.body?.secret
    if !secret
      return sendError(new restify.InvalidContentError('invalid content'), next)
    if secret != process.env.API_SECRET
      return sendError(new restify.UnauthorizedError('not authorized'), next)

    # Make sure secret isn't sent in clear to the users
    delete req.body.secret
    next()

  # Long Poll midlleware
  longPollMiddleware = (req, res, next) ->
    if (res.headersSent)
      return next()

    query = req.params.messagesQuery

    longPoll.add query.username,
      () ->
        queue.getMessages query, (err, messages) ->
          if err then sendError(err, next) else res.json(messages)
      () ->
        res.json([])

  #
  # Endpoints
  #

  # Retrieve the list of messages for a user
  getMessages = (req, res, next) ->
    query =
      username: req.params.user.username

    if req.query.hasOwnProperty('after')
      query.after = +req.query.after
      if !isFinite(query.after) || query.after < 0
        restErr = new restify.InvalidContentError('invalid content')
        return sendError(restErr, next)

    # load all recent messages
    queue.getMessages query, (err, messages) ->
      if err
        return sendError err, next

      # if there's data to send, send it right away
      if messages.length > 0
        res.json(messages)

      req.params.messagesQuery = query
      next()

  # Post a new message to a user
  postMessage = (req, res, next) ->
    # check that there is all required fields
    body = req.body
    if !body.to || !body.from || !body.type || !body.data
      return sendError(new restify.InvalidContentError('invalid content'), next)

    body.timestamp = Date.now()

    # add the message to the user's list
    queue.addMessage body.to, body, (err, messageId) ->
      if err
        return sendError(err, next)

      reply =
        id: messageId
        timestamp: body.timestamp

      # notify user that he has a message and respond to request
      pubsub.publish(body.to)
      res.json(reply)
      next()

  return (prefix, server) ->
    server.get "/#{prefix}/auth/:authToken/messages",
      authMiddleware, getMessages, longPollMiddleware
    server.post "/#{prefix}/messages", apiSecretMiddleware, postMessage

module.exports = notificationsApi

# vim: ts=2:sw=2:et:

log = require "../log"
authdb = require "authdb"
redis = require "redis"
restify = require "restify"
ganomedeHelpers = require 'ganomede-helpers'
config = require '../../config'
PubSub = require './pubsub'
Queue = require './queue'
LongPoll = require './long-poll'
hasOwnProperty = Object.prototype.hasOwnProperty

sendError = (err, next, type='error') ->
  log[type] err
  next err

sendShortError = (err, next, type='error') ->
  log[type] err.message
  next err

notificationsApi = (options={}) ->
  #
  # Init
  #

  # configure authdb client
  authdbClient = options.authdbClient || authdb.createClient(
    host: config.authdb.host
    port: config.authdb.port)

  # Some notifications may require sending push notification.
  # This function is called with `message` to be sent in it.
  # It is meant to store message into redis queue that holds push notifications
  # to be sent out.
  addPushNotification = options.addPushNotification
  if !addPushNotification
    log.warn('No options.addPushNotification() function provided
              to notificationsApi(). It will be noop()')
    addPushNotification = ->

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
      , (err, result) ->

  #
  # Middlewares
  #

  # Populates req.params.user with value returned from authDb.getAccount()
  authMiddleware = ganomedeHelpers.restify.middlewares.authdb.create({
    authdbClient,
    secret: config.secret
  })

  # Check the API secret key validity
  apiSecretMiddleware = (req, res, next) ->
    if !req.ganomede.secretMatches
      return sendError(new restify.UnauthorizedError('not authorized'), next)
    next()

  # Long Poll midlleware
  longPollMiddleware = (req, res, next) ->
    if (res.headersSent)
      return next()

    query = req.params.messagesQuery

    longPoll.add query.username,
      () ->
        queue.getMessages query, (err, messages) ->
          if err
            sendError(err, next)
          else
            res.json(messages)
            next()
      () ->
        res.json([])
        next()

  #
  # Endpoints
  #

  # Retrieve the list of messages for a user
  getMessages = (req, res, next) ->
    query =
      username: req.params.user.username

    if hasOwnProperty.call(req.query, 'after')
      query.after = +req.query.after
      if !isFinite(query.after)
        # || query.after < 0 (negative "after" allows to retrieve all message)
        restErr = new restify.InvalidContentError('invalid content')
        return sendError(restErr, next)

    # load all recent messages
    queue.getMessages query, (err, messages) ->
      if err
        return sendError err, next

      # if there's data to send, send it right away
      # also happens with special value after = -2
      if messages.length > 0 or query.after == -2
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
    queue.addMessage body.to, body, (err, message) ->
      if err
        return sendError(err, next)

      # If message has push object, it is also meant to be sent as
      # push notification.
      if hasOwnProperty.call(message, 'push')
        addPushNotification(message)

      reply =
        id: message.id
        timestamp: message.timestamp

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

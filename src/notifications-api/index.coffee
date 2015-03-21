log = require "../log"
authdb = require "authdb"
redis = require "redis"
restify = require "restify"
config = require '../../config'
PubSub = require './pubsub'
Queue = require './queue'

longPollDuration = 30000

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
    callListener username, true

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
    next()

  #
  # Endpoints
  #

  # Retrieve the list of messages for a user
  getMessages = (req, res, next) ->
    query =
      username: req.params.user.username
      after: +req.params.after

    # load all recent messages
    queue.getMessages query, (err, messages) ->
      if err
        return sendError err, next

      # if there's data to send, send it right away
      if messages.length > 0
        res.json(messages)
        return next()

      # no messages. wait up to longPollDuration milliseconds for one to arrive
      addListener query.username, (hasData) ->
        unless hasData
          # res.json([])
          # return next()
          return

        queue.getMessages query, (err, messages) ->
          if err
            return sendError err, next
          res.json(messages)
          next()

  # global list of listeners
  listeners = {}

  # call the listener if it exists
  callListener = (username, hasData) ->
    if listeners[username]
      l = listeners[username]
      delete listeners[username]
      clearTimeout l.timeout
      l.callback hasData


  # register a listener for a given user
  addListener = (username, callback) ->

    # already an existing listener? trigger it and replace
    callListener username, false

    # setup the timout
    timeout = setTimeout ->
      # on timeout
      delete listeners[username]
      callback false
    , longPollDuration

    # store the listener
    listeners[username] =
      callback: callback
      timeout: timeout

  # Post a new message to a user
  postMessage = (req, res, next) ->
    # check that there's is all required fields
    body = req.body
    if !body.to || !body.from || !body.type || !body.data
      return sendError(new restify.InvalidContentError('invalid content'), next)

    # add the message to the user's list
    queue.addMessage body.to, body, (err, messageId) ->
      if err
        return sendError(err, next)

      # notfiy user that he has a message and respond to request
      pubsub.publish(body.to)
      res.json({id: messageId})
      next()

  return (prefix, server) ->
    server.get "/#{prefix}/auth/:authToken/messages",
      authMiddleware, getMessages
    server.post "/#{prefix}/messages", apiSecretMiddleware, postMessage

module.exports = notificationsApi

# vim: ts=2:sw=2:et:

log = require "../log"
authdb = require "authdb"
redis = require "redis"
restify = require "restify"
vasync = require 'vasync'
config = require '../../config'
PubSub = require './pubsub'

redisClient = null
authdbClient = null
apiSecret = null
msgQueueSize = null
longPollDuration = 30000

sendError = (err, next) ->
  log.error err
  next err

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
  if secret != apiSecret
    return sendError(new restify.UnauthorizedError('not authorized'), next)
  next()


# extract a parsed list of messages.
# fails gently if invalid data is found
extractMessages = (json, username, after) ->
  ret = []

  try
    # if a "after" filter has been set, only returns messages
    # more recent than the provided id.
    if after
      for s in json
        msg = JSON.parse(s)
        # notes:
        #  - ids are auto-incremental
        #  - message are ordered newest to oldest
        # so it's valid to break when "after" has been found.
        if msg.id == after
          break
        if msg.id
          ret.push msg
    else
      # no filter, send the whole array
      for s in json
        msg = JSON.parse(s)
        if msg.id
          ret.push msg

  catch error
    # ignore the error, hopefully we parsed the most recent messages
    log.warn "JSON Parse Error", username: username, error

  return ret


# Retrieve the list of messages for a user
getMessages = (req, res, next) ->

  username = req.params.user.username
  after = +req.params.after

  # load all recent messages
  redisClient.lrange username, 0, msgQueueSize - 1, (err, json) ->

    if err
      return sendError err, next

    # extract the list of messages
    ret = extractMessages json, username, after

    # if there's data to send, send it right away
    if ret.length > 0
      res.send ret
      return next()

    # no messages. wait up to 30 seconds for one to arrive
    addListener username, (hasData) ->
      if (hasData)
        redisClient.lrange username, 0, msgQueueSize - 1, (err, json) ->
          if err
            sendError err, next
          else
            ret = extractMessages json, username, after
            res.send ret
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


# called when new data is available for a user
onMessage = (channel, username) ->

  # if there's a listener, trigger it
  callListener username, true


# Post a new message to a user
postMessage = (req, res, next) ->

  # check that there's is all required fields
  body = req.body
  if !body.to || !body.from || !body.type || !body.data
    return sendError(new restify.InvalidContentError('invalid content'), next)

  # generate a new message id
  redisClient.incr "@", (err, nextId) ->
    if err
      return sendError err, next

    # add the message to the user's list
    log.info "creating message id #{nextId}"
    body.id = nextId
    redisClient.lpush body.to, JSON.stringify(body), (err, data) ->
      if err
        return sendError err, next
      res.send
        id: "" + nextId

      # send notification to listeners
      redisClient.publish "post", body.to

      # ltrim after we're done (no need to slow down answering the client)
      redisClient.ltrim body.to, 0, msgQueueSize, (err, json) ->
        # we can just ignore the result of the ltrim command.

      next()

#
# Init
#

initialize = (options={}) ->
  # configure api secret
  apiSecret = options.apiSecret || process.env.API_SECRET

  # configure message queue
  msgQueueSize = options.msgQueueSize || config.redis.queueSize

  # configure authdb client
  authdbClient = options.authdbClient || authdb.createClient(
    host: config.authdb.host
    port: config.authdb.port)

  # notificatinos redis pub/sub
  pubsub = options.pubsub || new PubSub
    publisher: redis.createClient(config.redis.port, config.redis.host)
    subscriber: redis.createClient(config.redis.port, config.redis.host)
    channel: config.redis.channel

  # notify the listeners of incoming messages
  pubsub.subscribe(onMessage)

  # configure the redis client
  #
  # TODO:
  # hide all the interaction into PubSub
  redisClient = pubsub.pub

  # configure the testuser authentication token (to help with manual testing)
  if process.env.TESTUSER_AUTH_TOKEN
    authdbClient.addAccount process.env.TESTUSER_AUTH_TOKEN,
      username: "testuser"
      email: "testuser@fovea.cc"
      , (err, result) ->

addRoutes = (prefix, server) ->
  server.get "/#{prefix}/auth/:authToken/messages", authMiddleware, getMessages
  server.post "/#{prefix}/messages", apiSecretMiddleware, postMessage

module.exports =
  addRoutes: addRoutes
  initialize: initialize

# vim: ts=2:sw=2:et:

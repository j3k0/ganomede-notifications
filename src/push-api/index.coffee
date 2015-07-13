restify = require 'restify'
redis = require 'redis'
AuthDB = require 'authdb'
helpers = require 'ganomede-helpers'
Token = require './token'
TokenStorage = require './token-storage'
Sender = require './sender'
config = require '../../config'
log = require '../log'

module.exports = (options={}) ->
  tokenStorage = options.tokenStorage || new TokenStorage(
    redis.createClient(
      config.pushApi.redisPort,
      config.pushApi.redisHost,
        no_ready_check: true
  )

  sender = options.sender || new Sender(tokenStorage.redis, tokenStorage)

  authdb = options.authdb || AuthDB.createClient(
    host: config.authdb.host
    port: config.authdb.port
  )

  authMiddleware = helpers.restify.middlewares.authdb.create({
    authdbClient: authdb
  })

  savePushToken = (req, res, next) ->
    unless req.body && req.body.app && req.body.type && req.body.value &&
           req.body.type in Token.TYPES
      return next(new restify.InvalidContentError)

    token = Token.fromPayload
      username: req.params.user.username
      app: req.body.app
      type: req.body.type
      value: req.body.value

    tokenStorage.add token, (err, added) ->
      if (err)
        log.error 'Failed to add token',
          err: err
          token: token
        return next(new restify.InternalServerError)

      res.send(200)
      next()

  api = (prefix, server) ->
    server.post "/#{prefix}/auth/:authToken/push-token",
      authMiddleware, savePushToken

  api.addPushNotification = sender.addNotification.bind(sender)

  return api

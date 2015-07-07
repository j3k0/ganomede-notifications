vasync = require 'vasync'
pkg = require '../../package.json'
config = require '../../config'
Token = require './token'

class Sender
  constructor: (@redis, @tokenStorage) ->
    unless @redis
      throw new Error('RedisClientRequired')

    unless @tokenStorage
      throw new Error('TokenStorageRequired')

  # Sends push notification from the queue.
  # task is JS object with following fields:
  #   notification — actual payload
  #   tokens — Push Tokens (instance of Token)
  @send: (task, callback) ->
    vasync.forEachParallel
      func: (token, cb) ->
        switch token.type
          when Token.APN then cb(null, "#{Token.APN}-sent")
          when Token.GCM then cb(null, "#{Token.GCM}-sent")
          else cb(new Error('UknownTokenType'))
      inputs: task.tokens
    , callback

  # Look into redis list for new push notifications to be send.
  # If there are notification, retrieve push tokens for them.
  # callback(err, task)
  _rpop: (callback) ->
    @redis.rpop Sender.PREFIX, (err, notificationJson) ->
      callback(err, if err then null else JSON.parse(notificationJson))

  _task: (notification, callback) ->
    unless notification
      return callback(null, null)

    @tokenStorage.get notification.to, notification.from, (err, tokens) ->
      task =
        notification: notification
        tokens: tokens

      callback(err, if err then null else task)

  nextTask: (callback) ->
    vasync.waterfall [
      @_rpop.bind(@)
      @_task.bind(@)
    ], callback

Sender.PREFIX = [
  Token.removeServiceVersion(pkg.api), config.pushApi.queuePrefix
].join(':')

module.exports = Sender

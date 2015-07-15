apn = require 'apn'
vasync = require 'vasync'
config = require '../../config'
Token = require './token'
Task = require './task'
log = require '../log'
config = require '../../config'

# TODO
# listen for errors:
# https://github.com/argon/node-apn/blob/master/doc/connection.markdown
class ApnSender
  constructor: (options) ->
    @connection = new apn.Connection(
      production: !config.debug,
      cert: options.cert,
      key: options.key
    )

  # TODO
  # errors?
  send: (notification, tokens, callback) ->
    devices = tokens.map (token) -> new apn.Device(token.data())
    @connection.pushNotification(notification, devices)
    @connection.once('completed', callback.bind(null, null))

  close: () ->
    @connection.shutdown()

class Sender
  constructor: (@redis, @tokenStorage, @senders={}) ->
    unless @redis
      throw new Error('RedisClientRequired')

    unless @tokenStorage
      throw new Error('TokenStorageRequired')

  # Sends push notification from task.notification for each one of task.tokens.
  send: (task, callback) ->
    # Group tokens by type
    grouppedTokens = {}
    task.tokens.forEach (token) ->
      grouppedTokens[token.type] = grouppedTokens[token.type] || []
      grouppedTokens[token.type].push(token)

    # For each token group, invoke appropriate sender
    sendFunctions = []
    for own type, tokens of grouppedTokens
      sender = @senders[type]
      if !sender
        throw new Error("No sender specified for #{type} token type")

      fn = sender.send.bind(sender, task.convert(type), tokens)
      sendFunctions.push(fn)

    # Exec those functions
    vasync.parallel({funcs: sendFunctions}, callback)

  # Look into redis list for new push notifications to be send.
  # If there are notification, retrieve push tokens for them.
  # callback(err, task)
  _rpop: (callback) ->
    @redis.rpop config.pushApi.notificationsPrefix, (err, notificationJson) ->
      callback(err, if err then null else JSON.parse(notificationJson))

  _task: (notification, callback) ->
    unless notification
      return callback(null, null)

    @tokenStorage.get notification.to, notification.push.app, (err, tokens) ->
      if tokens.length == 0
        log.warn 'Found no push tokens for sending notification', notification

      ok = !err && tokens.length
      callback(err, if ok then new Task(notification, tokens) else null)

  nextTask: (callback) ->
    vasync.waterfall [
      @_rpop.bind(@)
      @_task.bind(@)
    ], callback

  # Add notification
  addNotification: (notification, callback=->) ->
    json = JSON.stringify(notification)
    @redis.lpush config.pushApi.notificationsPrefix, json, (err, newLength) ->
      if (err)
        log.error 'Sender#addNotification() failed',
          err: err
          notification: notification

      callback(err)

Sender.ApnSender = ApnSender
module.exports = Sender

# Redis queue that stores push notifications to be sent.

vasync = require 'vasync'
Task = require './task'
config = require '../../config'
log = require '../log'

class Queue
  constructor: (@redis, @tokenStorage) ->
    unless @redis
      throw new Error('RedisClientRequired')

    unless @tokenStorage
      throw new Error('TokenStorageRequired')

  # Add notification to the queue.
  # callback(err)
  add: (notification, callback=->) ->
    json = JSON.stringify(notification)
    @redis.lpush config.pushApi.notificationsPrefix, json, (err, newLength) ->
      if (err)
        log.error {
          err: err
          notification: notification
          queue: config.pushApi.notificationsPrefix
        }, 'Failed to add notification to the queue',

      callback(err, newLength)

  # Look into redis list for new push notifications to be send.
  # If there are notification, retrieve push tokens for them.
  # callback(err, task)
  _rpop: (callback) ->
    @redis.rpop config.pushApi.notificationsPrefix, (err, notificationJson) ->
      if err
        log.error {err}, 'Failed to .rpop push notification'
        return callback(err)

      callback(null, JSON.parse(notificationJson))

  _task: (notification, callback) ->
    now = +new Date()
    ten_minutes_ago = now - 600 * 1000
    tooOld = n -> n.timestamp and n.timestamp < ten_minutes_ago
    if (not notification) or tooOld(notification)
      return callback(null, null)

    @tokenStorage.get notification.to, notification.push.app, (err, tokens) ->
      if err
        log.error {
          err: err
          notification: notification
        }, 'Failed to get tokens for notification'
        return callback(err)

      if notification.secret
        delete notification.secret

      callback(null, new Task(notification, tokens))

  get: (callback) ->
    vasync.waterfall [
      @_rpop.bind(@)
      @_task.bind(@)
    ], callback

module.exports = Queue

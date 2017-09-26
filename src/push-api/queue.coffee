# Redis queue that stores push notifications to be sent.

vasync = require 'vasync'
Task = require './task'
config = require '../../config'
log = require '../log'
PushTranslator = require './push-translator'

class Queue
  constructor: (@redis, @tokenStorage) ->
    unless @redis
      throw new Error('RedisClientRequired')

    unless @tokenStorage
      throw new Error('TokenStorageRequired')

    @translator = new PushTranslator()

  # Add notification to the queue.
  # callback(err)
  add: (notification, callback=->) ->
    @translator.process notification, (err, translated) =>
      if (err)
        log.error 'Failed to translate notification', {err, notification}
        return callback(err)

      # Let's JSON translated notification, but maybe it is worth
      # to serialize original one in case of error. However, I do not plan
      # to ever error in translator for now.
      json = JSON.stringify(translated)

      @redis.lpush config.pushApi.notificationsPrefix, json, (err, newLength) ->
        if (err)
          log.error 'Failed to add translated notification to the queue',
            err: err
            notification: notification
            translated: translated
            queue: config.pushApi.notificationsPrefix

        callback(err, newLength)

  # Look into redis list for new push notifications to be send.
  # If there are notification, retrieve push tokens for them.
  # callback(err, task)
  _rpop: (callback) ->
    @redis.rpop config.pushApi.notificationsPrefix, (err, notificationJson) ->
      if err
        log.error 'Failed to .rpop push notification', err
        return callback(err)

      callback(null, JSON.parse(notificationJson))

  _task: (notification, callback) ->
    unless notification
      return callback(null, null)

    @tokenStorage.get notification.to, notification.push.app, (err, tokens) ->
      if err
        log.error 'Failed to get tokens for notification',
          err: err
          notification: notification
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

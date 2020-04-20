# Redis queue that stores push notifications to be sent.

vasync = require 'vasync'
Task = require './task'
config = require '../../config'
log = require '../log'
Translator = require './translator'

translator = new Translator()

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


  # Example notification data:
  #    notification: {
  #   "from": "chat/v1",
  #   "to": "kago042",
  #   "type": "message",
  #   "data": {
  #     "roomId": "triominos/v1/kago042/nipe755",
  #     "from": "nipe755",
  #     "timestamp": "1587367081025",
  #     "type": "triominos/v1",
  #     "message": "yo"
  #   },
  #   "push": {
  #     "titleArgsTypes": [
  #       "directory:name"
  #     ],
  #     "messageArgsTypes": [
  #       "string",
  #       "directory:name"
  #     ],
  #     "message": [
  #       "new_message_message",
  #       "yo",
  #       "nipe755"
  #     ],
  #     "app": "triominos/v1",
  #     "title": [
  #       "new_message_title",
  #       "nipe755"
  #     ]
  #   },
  #   "timestamp": 1587367081519,
  #   "id": 1132529133
  # }
  _task: (notification, callback) ->
    now = +new Date()
    ten_minutes_ago = now - 600 * 1000
    tooOld = (n) -> n.timestamp and n.timestamp < ten_minutes_ago
    if not notification
      return callback(null, null)
    if tooOld(notification)
      log.info {
        id: notification.id
        timestamp: (new Date(notification.timestamp)).toISOString()
      }, '[skip] notification is too old'
      return callback(null, new Task(notification, []))

    if notification.to == 'kago042'
      log.info {notification}, 'Sending notification to test user'

    @tokenStorage.get notification.to, notification.push.app, (err, tokens) ->
      # token data:
      # tokens: [{
      # "key": "notifications:push-tokens:data-v2:kago042:triominos/v1",
      #   "type": "gcm",
      #   "device": "defaultDevice",
      #   "value": "qjeklwqjeklwqje---some-garbage"
      # }]
      if err
        log.error {
          err: err
          notification: notification
        }, 'Failed to get tokens for notification'
        return callback(err)

      if notification.secret
        delete notification.secret

      # only send gcm push to test user for now
      if notification.to == 'kago042'
        log.info {tokens}, 'Tokens for test user'
      else
        tokens = tokens.filter((t) -> t.type != 'gcm')

      if tokens.length > 0
        translator.translate(
          notification.push.title,
          notification.push.titleArgsTypes,
          (title) ->
            translator.translate(
              notification.push.message,
              notification.push.messageArgsTypes,
              (message) ->
                if title and message
                  notification.translated =
                    title: title
                    message: message
                  callback(null, new Task(notification, tokens))
                else
                  callback(null, new Task(notification, []))
            )
        )
      else
        callback(null, new Task(notification, []))
  get: (callback) ->
    vasync.waterfall [
      @_rpop.bind(@)
      @_task.bind(@)
    ], callback

module.exports = Queue

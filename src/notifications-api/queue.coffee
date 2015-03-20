vasync = require 'vasync'
log = require '../log'

class Queue
  constructor: (redis) ->
    @redis = redis

    if !@redis
      throw new Error('Queue() requires redis client')

  nextId: (callback) ->
    @redis.incr '@', (err, id) ->
      if (err)
        log.error 'Queue#nextId() failed',
          err: err
        return callback(err)

      callback(null, String(id))

  # TODO:
  # trim queue, possibly via multi()
  #
  # callback(err, messageId)
  addMessage: (username, message, callback) ->
    vasync.waterfall [
      @nextId.bind(@)
      (id, cb) =>
        message.id = id
        log.info 'Queue#addMessage() creating new message',
          id: message.id
          username: username

        @redis.lpush username, JSON.stringify(message), (err, newLength) ->
          # TODO:
          # trim list if new Length is greater than max
          if (err)
            log.error 'Queue#addMessage() failed',
              err: err
            return cb(err)

          cb(null, id)
    ], callback

  # TODO:
  # catch JSON.parse() exceptions
  #
  # callback(err, messages)
  getMessages: (username, callback) ->
    @redis.lrange username, 0, -1, (err, messages) ->
      if (err)
        log.error 'Queue#getMessages() failed',
          err: err,
          username: username
        return callback(err)

      callback null, messages.map (m) -> JSON.parse(m)

module.exports = Queue

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

  # callback(err, messages)
  getMessages: (query, callback) ->
    if (typeof query == 'string')
      query = {username: query}

    @redis.lrange query.username, 0, -1, (err, messages) ->
      if (err)
        log.error 'Queue#getMessages() failed',
          err: err,
          query: query
        return callback(err)

      callback null, Queue.filter(query, messages)

  @filter: (query, messages) ->
    ret = []

    try
      # if a "after" filter has been set, only returns messages
      # more recent than the provided id.
      if query?.after?
        for m in messages
          msg = JSON.parse(m)
          # notes:
          #  - ids are auto-incremental
          #  - message are ordered newest to oldest
          # so it's valid to break when "after" has been found.
          if msg.id == query.after
            break
          if msg.id
            ret.push msg
      else
        # no filter, send the whole array
        for m in messages
          msg = JSON.parse(m)
          if msg.id
            ret.push msg
    catch error
      # ignore JSON.parse() exceptions,
      # hopefully we parsed the most recent messages
      if error instanceof SyntaxError
        return log.warn 'Query.filter() faieled JSON.parse() step',
          query: query
          messages: messages
          error: error

      throw error

    return ret

module.exports = Queue

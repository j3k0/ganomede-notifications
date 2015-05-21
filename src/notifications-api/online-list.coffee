log = require '../log'

class OnlineList
  constructor: (redis, options={}) ->
    @redis = redis
    @maxRedisIndex = options.maxSize - 1
    @key = options.key || 'online-list'

    if !@redis
      throw new Error('OnlineList() requires a Redis client')

    if !isFinite(@maxRedisIndex) || (@maxRedisIndex < 0)
      throw new Error('OnlineList() requires options.maxSize to be Integer > 0')

  _add: (username, callback) ->
    @redis.multi()
      .lpush(@key, username)
      .ltrim(@key, 0, @maxRedisIndex)
      .exec(callback)

  add: (username, callback) ->
    @_add username, (err, replies) ->
      if (err)
        log.error 'OnlineList failed to add user',
          err: err
          replies: replies

      callback(err)

  get: (callback) ->
    @redis.lrange @key, 0, -1, (err, list) ->
      if (err)
        log.error 'OnlineList failed to retrieve list', {err: err}

      callback(err, list)

module.exports = OnlineList

log = require '../log'

# Stores list of users most recently online.
# Uses Redis' sorted set with score -timestamp of request.
class OnlineList
  constructor: (redis, options={}) ->
    @redis = redis
    @maxRedisIndex = options.maxSize
    @key = options.key || 'online-list'

    if !@redis
      throw new Error('OnlineList() requires a Redis client')

    if !isFinite(@maxRedisIndex) || (@maxRedisIndex < 0)
      throw new Error('OnlineList() requires options.maxSize to be Integer > 0')

  _add: (username, callback) ->
    # add user or update his position
    # remove oldest users
    @redis.multi()
      .zadd(@key, -Date.now(), username)
      .zremrangebyrank(@key, @maxRedisIndex, -1)
      .exec(callback)

  add: (username, callback) ->
    @_add username, (err, replies) ->
      if (err)
        log.error 'OnlineList failed to add user',
          err: err
          replies: replies

      callback(err)

  get: (callback) ->
    @redis.zrange @key, 0, -1, (err, list) ->
      if (err)
        log.error 'OnlineList failed to retrieve list', {err: err}

      callback(err, list)

module.exports = OnlineList

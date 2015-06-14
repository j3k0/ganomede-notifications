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

  _add: (username) ->
    # add user or update his position
    # remove oldest users
    # remove multi, enable pipeling and proxying
    @redis.zadd(@key, -Date.now(), username)
    @redis.zremrangebyrank(@key, @maxRedisIndex, -1)

  add: (username) ->
    @_add username

  get: (callback) ->
    @redis.zrange @key, 0, -1, (err, list) ->
      if (err)
        log.error 'OnlineList failed to retrieve list', {err: err}

      callback(err, list)

module.exports = OnlineList

log = require '../log'

# Stores list of users most recently online.
# Uses Redis' sorted set with score -timestamp of request.
# Options:
#   maxSize
#   prefix
#   invisibleEmailRe
class ListManager
  constructor: (redis, options={}) ->
    @redis = redis
    @maxRedisIndex = options.maxSize
    @prefix = options.prefix || 'online-list'
    @invisibleEmailRe = options.invisibleEmailRe || null

    if !@redis
      throw new Error('OnlineList() requires a Redis client')

    if !isFinite(@maxRedisIndex) || (@maxRedisIndex < 0)
      throw new Error('OnlineList() requires options.maxSize to be Integer > 0')

  key: (listId) ->
    id = listId || 'default'
    return "#{@prefix}:#{id}"

  userVisible: (profile) ->
    valid = profile? && profile.username && profile.email
    if (!valid)
      return false

    if profile._secret
      return false

    if @invisibleEmailRe
      hidden = @invisibleEmailRe.test(profile.email)
      return !hidden

    return true

  add: (listId, profile, callback) ->
    done = (err) =>
      if (err)
        log.error("ListManager failed to update list #{id}", err)
        return callback && callback(err)

      if (callback)
        @get(listId, callback)

    if not @userVisible(profile)
      return done()

    key = @key(listId)

    # add user or update his position
    # remove oldest users
    @redis.multi()
      .zadd(key, -Date.now(), profile.username)
      .zremrangebyrank(key, @maxRedisIndex, -1)
      .exec(done)

  get: (listId, callback) ->
    key = @key(listId)

    @redis.zrange key, 0, -1, (err, list) ->
      if (err)
        log.error("ListManager failed to retrieve list #{id}", err)
        return callback(err)

      callback(null, list)

module.exports = ListManager
# vim: ts=2:sw=2:et:

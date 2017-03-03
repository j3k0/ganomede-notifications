log = require '../log'

# Stores list of users most recently online.
# Uses Redis' sorted set with score -timestamp of request.
# Options:
#   maxSize
#   prefix
#   invisibleUsernameRegExp
class ListManager
  constructor: (redis, options={}) ->
    @redis = redis
    @maxRedisIndex = options.maxSize
    @prefix = options.prefix || 'online-list'
    @invisibleUsernameRegExp = options.invisibleUsernameRegExp || null

    if !@redis
      throw new Error('OnlineList() requires a Redis client')

    if !isFinite(@maxRedisIndex) || (@maxRedisIndex < 0)
      throw new Error('OnlineList() requires options.maxSize to be Integer > 0')

  key: (listId) ->
    id = listId || 'default'
    return "#{@prefix}:#{id}"

  userVisible: (profile) ->
    if !profile?.username
      return false

    if profile._secret
      return false

    if @invisibleUsernameRegExp
      hidden = @invisibleUsernameRegExp.test(profile.username)
      return !hidden

    return true

  add: (listId, profile, callback) ->
    if not @userVisible(profile)
      return @get(listId, callback)

    key = @key(listId)

    # add user or update his position
    # remove oldest users
    # fetch updated list
    @redis.multi()
      .zadd(key, -Date.now(), profile.username)
      .zremrangebyrank(key, @maxRedisIndex, -1)
      .zrange(key, 0, -1)
      .exec (err, replies) ->
        if (err)
          log.error("ListManager failed to update list #{id}", err)
          return callback(err)

        callback(null, replies[2])

  get: (listId, callback) ->
    key = @key(listId)

    @redis.zrange key, 0, -1, (err, list) ->
      if (err)
        log.error("ListManager failed to retrieve list #{id}", err)
        return callback(err)

      callback(null, list)

module.exports = ListManager
# vim: ts=2:sw=2:et:

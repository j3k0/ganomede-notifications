Token = require './token'

class TokenStorage
  constructor: (redis) ->
    @redis = redis

  # Adds token to redis.
  # callback(err, added)
  add: (token, callback) ->
    @redis.sadd token.key, token.value, (err, nAdded) ->
      callback(err, if err then false else nAdded == 1)

  # Retrieves username's tokens for particular app
  get: (username, app, callback) ->
    key = Token.key(username, app)

    @redis.smembers key, (err, members) ->
      if (err)
        return callback(err)

      ret = members.map (value) -> new Token(key, value)
      callback(null, ret)


module.exports = TokenStorage

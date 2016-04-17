Token = require './token'

# Within redis hash we have
#  #{type:device}: value
toHashSubkey = (token) -> "#{token.type}:#{token.device}"
fromHashSubkey = (subkey, value) ->
  parts = subkey.split(':')
  return {
    type: parts[0],
    device: parts[1],
    value
  }

class TokenStorage
  constructor: (redis) ->
    @redis = redis

  # Adds token to redis.
  # callback(err, added)
  add: (token, callback) ->
    @redis.hset token.key, toHashSubkey(token), token.value, (err, reply) ->
      # 1 for adding
      # 0 for updating
      callback(err, reply == 1)

  # Retrieves username's tokens for particular app
  get: (username, app, callback) ->
    key = Token.key(username, app)

    @redis.hgetall key, (err, tokens) ->
      if (err)
        return callback(err)

      ret = []
      if tokens
        ret = Object.keys(tokens).map (subkey) ->
          parts = subkey.split(':')
          return new Token(key, fromHashSubkey(subkey, tokens[subkey]))

      callback(null, ret)

module.exports = TokenStorage

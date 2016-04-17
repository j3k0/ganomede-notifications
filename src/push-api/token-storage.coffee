Token = require './token'

class TokenStorage
  constructor: (redis) ->
    @redis = redis

  # Adds token to redis.
  # callback(err, added)
  add: (token, callback) ->
    @redis.hset token.key, token.type, token.value, (err, reply) ->
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
        ret = Object.keys(tokens).map((type) -> new Token(key, tokens[type]))

      callback(null, ret)

module.exports = TokenStorage

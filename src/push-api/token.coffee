config = require '../../config'

class Token
  constructor: (@key, @value) ->

  @key: (username, app) ->
    return [config.pushApi.redisPrefix, username, app].join(':')

  @value: (type, value) ->
    return [type, value].join(':')

  @fromPayload: (data) ->
    key = Token.key(data.username, data.app)
    value = Token.value(data.type, data.value)
    return new Token(key, value)

module.exports = Token

config = require '../../config'

class Token
  constructor: (@key, @value) ->
    @type = @value.slice(0, @value.indexOf(':'))

  @key: (username, app) ->
    return [config.pushApi.tokensPrefix, username, app].join(':')

  @value: (type, value) ->
    return [type, value].join(':')

  @fromPayload: (data) ->
    key = Token.key(data.username, data.app)
    value = Token.value(data.type, data.value)
    return new Token(key, value)

Token.APN = 'apn'
Token.GCM = 'gcm'
Token.TYPES = [Token.APN, Token.GCM]

module.exports = Token

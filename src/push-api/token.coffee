pkg = require '../../package.json'
config = require '../../config'

class Token
  constructor: (@key, @value) ->
    @type = value.slice(0, value.indexOf(':'))

  @key: (username, app) ->
    unversionedApp = Token.removeServiceVersion(app)
    return [Token.PREFIX, username, unversionedApp].join(':')

  @value: (type, value) ->
    return [type, value].join(':')

  @fromPayload: (data) ->
    key = Token.key(data.username, data.app)
    value = Token.value(data.type, data.value)
    return new Token(key, value)

  @removeServiceVersion: (name) ->
    pos = name.search(/\/v\d+/)
    return if -1 == pos then name else name.slice(0, pos)

Token.PREFIX = [
  Token.removeServiceVersion(pkg.api), config.pushApi.tokensPrefix
].join(':')

Token.APN = 'apn'
Token.GCM = 'gcm'
Token.TYPES = [Token.APN, Token.GCM]

module.exports = Token

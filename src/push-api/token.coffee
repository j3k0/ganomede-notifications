pkg = require '../../package.json'

class Token
  constructor: (@key, @value) ->
    @type = value.slice(0, value.indexOf(':'))

  @key: (username, app) ->
    return [Token.PREFIX, username, app].join(':')

  @value: (type, value) ->
    return [type, value].join(':')

  @fromPayload: (data) ->
    key = Token.key(data.username, data.app)
    value = Token.value(data.type, data.value)
    return new Token(key, value)

  @removeServiceVersion: (name) ->
    pos = name.search(/\/v\d+/)
    return if -1 == pos then name else name.slice(0, pos)

Token.PREFIX = [Token.removeServiceVersion(pkg.api), 'push-notifications']
  .join(':')

Token.IOS = 'ios'
Token.ANDROID = 'android'
Token.TYPES = [Token.IOS, Token.ANDROID]

module.exports = Token

config = require '../../config'

class Token
  constructor: (@key, {@type, @device, @value}) ->
    @device = @device || 'defaultDevice'
    if !@key then throw new Error('KeyMissing')
    if !@type then throw new Error('TypeMissing')
    if !@device then throw new Error('DeviceMissing')
    if !@value then throw new Error('ValueMissing')

  data: () -> @value

  @key: (username, app) ->
    return [config.pushApi.tokensPrefix, username, app].join(':')

  @value: (type, device='defaultDevice') ->
    return [type, device].join(':')

  @fromPayload: (data) ->
    key = Token.key(data.username, data.app)
    return new Token(key, data)

Token.APN = 'apn'
Token.GCM = 'gcm'
Token.TYPES = [Token.APN, Token.GCM]

module.exports = Token

sinon = require 'sinon'
Token = require '../../src/push-api/token'

exports.tokenData = () ->
  return {
    username: 'alice'
    app: 'substract-game/v1'
    type: 'apn'
    value: 'alicesubstracttoken'
  }

exports.notification = (push, reciever='alice') ->
  ret =
    from: 'substract-game/v1',
    to: reciever,
    type: 'invitation-created',
    data: {},
    timestamp: 1436269938903,
    id: 1

  if push
    ret.push = push

  return ret

exports.fakeSenders = () ->
  ret = {}
  for type in Token.TYPES
    fakeSend = (payload, tokens, callback) -> process.nextTick(callback)
    ret[type] = {send: sinon.spy(fakeSend)}

  return ret

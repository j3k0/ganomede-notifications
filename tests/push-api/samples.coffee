sinon = require 'sinon'
Token = require '../../src/push-api/token'

exports.tokenData = (type='apn', value='alicesubstracttoken') ->
  return {
    username: 'alice'
    app: 'substract-game/v1'
    type: type
    value: value
  }

exports.notification = (push={}, reciever='alice') ->
  ret =
    from: 'substract-game/v1',
    to: reciever,
    type: 'invitation-created',
    data: {},
    push: push,
    timestamp: 1436269938903,
    id: 1

  ret.push.app = ret.push.app || ret.from
  return ret

exports.fakeSenders = () ->
  ret = {}
  for type in Token.TYPES
    fakeSend = (payload, tokens, callback) -> process.nextTick(callback)
    ret[type] = {send: sinon.spy(fakeSend)}

  return ret

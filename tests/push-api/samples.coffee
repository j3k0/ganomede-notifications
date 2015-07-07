exports.tokenData = () ->
  return {
    username: 'alice'
    app: 'substract-game'
    type: 'ios'
    value: 'alicesubstracttoken'
  }

exports.notification = () ->
  return {
    from: 'substract-game/v1',
    to: 'alice',
    type: 'invitation-created',
    data: {},
    timestamp: 1436269938903,
    id: 1
  }

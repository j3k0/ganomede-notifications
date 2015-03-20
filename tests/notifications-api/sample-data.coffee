module.exports =
  notification: (secret) ->
    from: 'invitations/v1'
    to: 'bob'
    type: 'invitation-created'
    secret: secret
    data: {}

  malformedNotification: (secret) ->
    secret: secret

  users:
    alice:
      token: 'alice-token'
      account: {username: 'alice'}

    bob:
      token: 'bob-token'
      account: {username: 'bob'}

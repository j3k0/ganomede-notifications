module.exports =
  notification: (secret, reciever='bob', pushObj=null) ->
    ret =
      from: 'invitations/v1'
      to: reciever
      type: 'invitation-created'
      secret: secret
      data: {}

    if pushObj
      ret.push = pushObj

    return ret

  malformedNotification: (secret) ->
    secret: secret

  users:
    alice:
      token: 'alice-token'
      account: {username: 'alice'}

    bob:
      token: 'bob-token'
      account: {username: 'bob'}

    pushNotified:
      token: 'push-notified-token'
      account: {username: 'push-notified'}

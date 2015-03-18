This document describes how [Invitations module](https://github.com/j3k0/ganomede-invitations) and [Notifications module](https://github.com/j3k0/ganomede-notifications) interact with each other and their clients.
See [#3](https://github.com/j3k0/ganomede-notifications/issues/3) for discussion.

## Notification Types

#### `invitation` to play a multiplayer game.

```js
{
  "type": "invitation",   // Type of notification
  "data": {
    "action": "created",  // String representing state of the invitation
    "invitation": {}      // Object containing Invitation data (see invitations module)
  }
}
```

Invite notification's data can contain different `action` values representing state of the invite:

  * `created` notifies invitation receiver, who can `reject` or `accept` it.
  * `accepted` notifies invitation sender, that his invite has been accepted.
  * `rejected` notifies invitation sender, that his invite has been rejected.

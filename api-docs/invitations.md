![notifications-workflow](https://cloud.githubusercontent.com/assets/886388/6689803/53fdbeb8-ccde-11e4-9e39-e1ce651ffe4d.png)

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

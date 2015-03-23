This document describes how [Invitations module](https://github.com/j3k0/ganomede-invitations) and [Notifications module](https://github.com/j3k0/ganomede-notifications) interact with each other and their clients.
See [#3](https://github.com/j3k0/ganomede-notifications/issues/3) for discussion.

## Notification Types

Every notification type has `from` field set to `invitations/v1` and contains `data.invitation` with actual invitation data.

```js
{
  "type": "String",      // Type of notification
  "data": {
    "reason": "String",  // Reason
    "invitation": {}     // Invitation data (see invitations module)
  }
}
```

Following are types of notificatinos from invitation module and reasons they were recieved by API client:

* `invitation-created` Someone invited notification receiver to play a game, `data.reason` is not included.
* `invitation-deleted` means invitation was deleated, `data.reason` could be:
  - `accept` invitation receiver accepted invitation;
  - `refuse` invitation receiver refused invitation;
  - `cancel` invitation sender canceled invitation.

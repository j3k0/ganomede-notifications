This document describes how [Coordinator module](https://github.com/j3k0/ganomede-coordinator) and [Notifications module](https://github.com/j3k0/ganomede-notifications) interact with each other and their clients.
See [#20](https://github.com/j3k0/ganomede-notifications/issues/20) for discussion.

## Notification Types

Every notification type has `from` field set to `coordinator/v1`.

Following are types of notificatinos from coordinator module:

### type = `leave`

Someone left a game you're participating. Every active player participating will receive this notification except the one that left (or those that already left).

Notification `data` will include:

```json
{
  "data": {
    "game": {
      "id": "ab12345789",
      "type": "triominos/v1",
      "players": [ "some_username_1", "some_username_2" ]
    },
    "player": "some_username_1",
    "reason": "resign"
  }
}
```

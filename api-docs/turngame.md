This document describes how [Turngame module](https://github.com/j3k0/ganomede-turngame) and [Notifications module](https://github.com/j3k0/ganomede-notifications) interact with each other and their clients. See [#9](https://github.com/j3k0/ganomede-notifications/issues/9) for discussion.

## Notification Types

Every notification type has `from` field set to `turngame/v1`.

Following are types of notificatinos from turngame module:

* `move` Someone performed move in a game you're participating. Every player participating will recieve this notification except the one making move.
`data.game` will include game info:
```js
"data": {
  "game": {
    "id": "ab12345789",
    "type": "triominos/v1",
    "players": [ "some_username_1", "some_username_2" ],
    "turn": "some_username_1",
    "status": "active",
    "gameData": { ... }
  }
}
```


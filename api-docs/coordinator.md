This document describes how [Coordinator module](https://github.com/j3k0/ganomede-coordinator) and [Notifications module](https://github.com/j3k0/ganomede-notifications) interact with each other and their clients.
See [#20](https://github.com/j3k0/ganomede-notifications/issues/20) for discussion.

## Notification Types

Every notification type has `from` field set to `coordinator/v1`.

Coordinator sends out 2 types of notifications that are bascially the same: `leave` and `join` for notifying players that someone leaved or joined a game they are participating in. Every active player participating will receive this notifications except the one that left or joined.

(Active players are those who joined the game and didn't left it.)

Notification `data` will include:

``` json
{
  "data": {
    // basic game info
    "game": {
      "id": "ab12345789",
      "type": "triominos/v1",
      "players": [ "some_username_1", "some_username_2" ]
    },
    "player": "some_username_1",  // username of a player who left/joined
    "reason": "resign"  // `resign` for `leave`, not included in `join`.
  }
}
```

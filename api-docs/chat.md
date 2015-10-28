This document describes how [Chat module](https://github.com/j3k0/ganomede-chat) and [Notifications module](https://github.com/j3k0/ganomede-notifications) interact with each other and their clients.

## Notification Types

Every notification type has `from` field set to `chat/v1`.

Chat sends only 1 types of notifications — `message`. Every user except in a chat room except message sender will receive a notifications about new messages added to that room.

Notification `data` will include Room ID and added message:

``` js
{
  "data": {
    // Room ID
    "roomId": "game/v1/alice/bob"
    // Message
    "timestamp": 1429084002258,           // JS timestamp
    "from": "bob",                        // Sender's username
    "type": "text",                       // Type of message
    "message": "Good thanks, let's play"  // Message text
  }
}
```

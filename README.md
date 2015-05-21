Notifications
-------------

This module allows a player to be notified of events using [long-polling](#retrieve-recent-messages-get).

Notificatinos are created by other ganomede services by [posting notification](#send-a-message-post):

  * [Invitations module](/api-docs/invitations.md)
  * [Turngame module](/api-docs/turngame.md)

Notificatinos from different services will be of different `type` and will contain different `data`, but following fields will always be present in every notification:

```js
{ "id": '12',                  // String       Notification ID
  "timestamp": 1429084002258,  // JSTimestmap  Created at this time
  "from": "turngame/v1",       // String       Created by this service

  "type": "invitation",            // String  Notification type (depends on the service)
  "data": {}                       // Object  Notification data (depends on the service and type)
}
```

Relations
---------

 * "AuthDB" (Redis) -> to check authentication status of user making requests
   * see https://github.com/j3k0/node-authdb
 * "NofificationsDB"
   * store "username" -> Array of notifications (trimmed to 50)

Configuration
-------------

Variables available for service configuration (see [config.js](/config.js)):

 * `PORT`
 * `ROUTE_PREFIX`
 * `REDIS_AUTH_PORT_6379_TCP_ADDR` — IP of the AuthDB redis
 * `REDIS_AUTH_PORT_6379_TCP_PORT` — Port of the AuthDB redis
 * `REDIS_NOTIFICATIONS_PORT_6379_TCP_ADDR` — Redis notifications host
 * `REDIS_NOTIFICATIONS_PORT_6379_TCP_PORT` — Redis notifications port
 * `MESSAGE_QUEUE_SIZE` — Redis notifications queue size
 * `ONLINE_LIST_SIZE` — Redis list size with users most recently online
 * `API_SECRET` — Secret passcode required to send notifications

AuthDB
------

 * Contains a store "authToken" -> { "username": "someusername", ... }
 * Access it using node-authdb (https://github.com/j3k0/node-authdb)

API
---

# Users Messages [/notifications/v1/auth/:authToken/messages]

    + Parameters
        + authToken (string, required) ... Authentication token

## Retrieve recent messages [GET]

    + GET parameters
        + after (integer) ... All message received after the one with given ID

Will retrieve all recent messages for the given user. In case no new messages are available, the request will wait for data until a timeout occurs.

### response [200] OK

    [{
        "id": 12,
        "timestamp": 1429084002258,
        "from": "turngame/v1",
        "type": "MOVE",
        "data": { ... }
    },
    {
        "id": 19,
        "timestamp": 1429084002258,
        "from": "invitations/v1",
        "type": "INVITE",
        "data": { ... }
    }]

### response [401] Unauthorized

If authToken is invalid.

# Messages [/notifications/v1/messages]

## Send a message [POST]

### body (application/json)

    {
        "to": "some_username",
        "from": "turngame/v1",
        "secret": "some secret passphrase",
        "type": "MOVE",
        "data": { ... }
    }

### response [200] OK

    {
        "id": 12
        "timestamp": 1429084002258
    }

### response [401] Unauthorized

If secret is invalid.

### design note

The value of "secret" should be equal to the `API_SECRET` environment variable.

# Online User List [/notifications/v1/online]

Every time client sends request for retrieving messages for a particular user, that user is added to a top of the list of recently online users in Redis.

List is trimmed at `ONLINE_LIST_SIZE` most recent users.

## Retrive List [GET]

Will return a list of usernames of most recently online users. This list is publicly available (no `API_SECRET` or auth required).

### response [200] OK

    [ "username",
      "alice",
      ...
      "bob"
    ]


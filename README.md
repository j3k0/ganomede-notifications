Notifications
-------------

This module allows a player to be notified of events using long-polling.

Relations
---------

 * "AuthDB" (Redis) -> to check authentication status of user making requests
   * see https://github.com/j3k0/node-authdb
   * ask for sample code to JC
 * "NofificationsDB"
   * store "username" -> Array of notifications (trimmed to 50)

Configuration
-------------

Variables available for service configuration.

 * `REDIS_AUTH_PORT_6379_TCP_ADDR` - IP of the AuthDB redis
 * `REDIS_AUTH_PORT_6379_TCP_PORT` - Port of the AuthDB redis
 * `REDIS_NOTIFICATIONS_PORT_6379_TCP_ADDR` - IP of the AuthDB redis
 * `REDIS_NOTIFICATIONS_PORT_6379_TCP_PORT` - Port of the AuthDB redis

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
        "date": "2014-12-01T12:00:00Z",
        "from": "turngame/v1",
        "type": "MOVE",
        "data": { ... }
    },
    {
        "id": 19,
        "date": "2014-12-01T12:40:10Z",
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
    }

### response [401] Unauthorized

If secret is invalid.


Notifications
-------------

This module allows a player to be notified of events using [long-polling](#retrieve-recent-messages-get).

Notificatinos are created by other ganomede services by [posting notification](#send-a-message-post):

  * [Invitations module](/api-docs/invitations.md)
  * [Turngame module](/api-docs/turngame.md)
  * [Coordinator module](/api-docs/turngame.md)
  * [Chat module](/api-docs/chat.md)

Notificatinos from different services will be of different `type` and will contain different `data`, but following fields will always be present in every notification:

```js
{ "id": '12',                  // String       Notification ID
  "timestamp": 1429084002258,  // JSTimestmap  Created at this time
  "from": "turngame/v1",       // String       Created by this service

  "type": "invitation",            // String  Notification type (depends on the service)
  "data": {}                       // Object  Notification data (depends on the service and type)
  "push": {}                       // Object  Optional, include if you want this notification to be also sent as push-notification to user devices.
}
```

Notifications containing `.push` object will also be sent as push notifications to user devices. Payload of that push notification will contain original ganomede notification. Fields in `.push` describe how notification will be displayed to user.

``` js
{ "app": "triominos/v1"  // String, required  Which app to notify

  "title": [ "localization-key", "args..." ],   // String[], optional
  "message": [ "localization-key", "args..." ], // String[], optional
  "titleArgsTypes": [ ],                        // String[], optional
  "messageArgsTypes": [ "username..." ]         // String[], optional
}
```

`.push.title` and `.push.message` must be String arrays of at least 1 length containing localization key at `[0]` followed by any number of localization arguments. If either title, or message, or both are not present, notificaiton alert will default to `config.pushApi.apn.defaultAlert` string.

`.push.messageArgsTypes` and `.push.titleArgsTypes` define the types of localization arguments. Use specific types here so service will perform lookups and expand your arguments into "better-looking" strings. For example:

``` js
// Based in userIds, this…

{ "title": [ "invite-title", "Invitation mailed to ", "alice" ],
  "titleArgsTypes": [ "string", "directory:email" ],

  "message": [ "invite-message", "bob", " invited you somewhere nice. Details are in your email, ", "alice", "." ],
  "messageArgsTypes": [ "directory:username", "string", "directory:username", "string" ]
}

// …will get expanded to this:

{ "title": [ "invite-title", "Invitation mailed to ", "alice@wonderland.com" ],
  "titleArgsTypes": [ "string", "directory:email" ],

  "message": [ "invite-message", "Magnificent Bob", " invited you somewhere nice. Details are in your email, ", "Alice of the Wonderland", "." ],
  "messageArgsTypes": [ "directory:username", "string", "directory:username", "string" ]
}
```

For now, only aliases are expanded from `userId`s via [ganomede-directory](https://github.com/j3k0/ganomede-directory). See [`translators.coffee`](/src/push-api/translators.coffee) for details.

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
 * `NODE_ENV` — Antything except `production` means that app is running in development (debug) mode
 * Notifications API
   - `REDIS_NOTIFICATIONS_PORT_6379_TCP_ADDR` — Redis notifications host
   - `REDIS_NOTIFICATIONS_PORT_6379_TCP_PORT` — Redis notifications port
   - `MESSAGE_QUEUE_SIZE` — Redis notifications queue size
   - `API_SECRET` — Secret passcode required to send notifications
 * Online List API
   - `ONLINE_LIST_SIZE` — Redis list size with users most recently online
   - `ONLINE_LIST_INVISIBLE_MATCH` - Regex matching invisible players
   - `REDIS_ONLINELIST_PORT_6379_TCP_ADDR` — Redis online list host
   - `REDIS_ONLINELIST_PORT_6379_TCP_PORT` — Redis online list port
 * Push Notifications API
   - `DIRECTORY_PORT_8000_TCP_[ADDR|PORT|PROTOCOL]` - Link to ganomede-directory (optional)
   - `REDIS_PUSHAPI_PORT_6379_TCP_ADDR` — Redis host for storing push tokens
   - `REDIS_PUSHAPI_PORT_6379_TCP_PORT` — Redis port for storing push tokens
   - `APN_CERT_FILEPATH` — Path to .pem file with APN certificate
   - `APN_CERT_BASE64` — Base64 encoded APN certificate (pem)
   - `APN_KEY_FILEPATH` — Path to .pem file with APN private key
   - `APN_KEY_BASE64` — Base64 encoded APN private key (pem)
   - `GCM_API_KEY` — API key for Google Cloud Messaging
   - `NODE_ENV` - set to production to connect to the production gateway. Otherwise it will connect to the sandbox.
 * Push Worker
   - `BATCH_SIZE` — Size of the batch of messages to process each iteration (default: 10)

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

# Legacy Online User List [/notifications/v1/online]

Alias to `/notifications/v1/online/default` (listid = default)

# Legacy Online status [/notifications/v1/auth/:authToken/online]

Alias to `/auth/:authToken/online/default` (listid = default)

# Online User List [/notifications/v1/online/:listid]

List of players in the the `listid` list of online users.

## Retrieve List [GET]

Will return a list of usernames of most recently online users. Lists are publicly available (no `API_SECRET` or auth required).

### response [200] OK

    [ "username",
      "alice",
      ...
      "bob"
    ]

# Online status [/notifications/v1/auth/:authToken/online/:listid]

User is online.

## Set as online [POST]

Add user to the list of online players with id `listid`, returns the list of users.

The list is trimmed at `ONLINE_LIST_SIZE` most recent users.

### response [200] OK

    [
      "username",
      "alice",
      ...
      "bob"
    ]

# Push Notifications API

## Save Push Token [POST /auth/:authToken/push-token]

Saves user's push notifications token to database. Example Body:

``` js
{
    app: 'substract-game',         // String, which app this token is for
    type: 'apn',                   // String, which push notifications provider
                                   //         this token is for, `apn` or `gcm`
                                   //         (see Token.TYPES)
    value: 'alicesubstracttoken'   // token value
}
```

# Push Notifications Worker

The server doesn't send push notifications, only add them to a task list. A worker will read from this task list and do the actual sending.

Worker is found in src/push-api/sender-cli.coffee

A way of running it continously is through the push-worker.sh script, that'll spawn one worker every second.

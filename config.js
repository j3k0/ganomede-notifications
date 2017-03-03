var path = require('path');
var pkg = require("./package.json");

function removeServiceVersion (name) {
  var pos = name.search(/\/v\d+/);
  return -1 === pos
    ? name
    : name.slice(0, pos);
}

var unversionedApi = removeServiceVersion(pkg.api);

module.exports = {
  port: +process.env.PORT || 8000,
  routePrefix: process.env.ROUTE_PREFIX || pkg.api,
  longPollDurationMillis: 30000,
  removeServiceVersion: removeServiceVersion,
  debug: process.env.NODE_ENV !== 'production',
  secret: (function () {
    const has = process.env.hasOwnProperty('API_SECRET');
    const val = process.env.API_SECRET;
    const ok = has && val && (typeof val === 'string') && (val.length > 0);

    // No need to throw, ganomede-helpers will throw for us.
    return ok ? val : null;
  }()),

  authdb: {
    host: process.env.REDIS_AUTH_PORT_6379_TCP_ADDR || 'localhost',
    port: +process.env.REDIS_AUTH_PORT_6379_TCP_PORT || 6379
  },

  redis: {
    host: process.env.REDIS_NOTIFICATIONS_PORT_6379_TCP_ADDR || 'localhost',
    port: +process.env.REDIS_NOTIFICATIONS_PORT_6379_TCP_PORT || 6379,
    queueSize: +process.env.MESSAGE_QUEUE_SIZE || 50,
    channel: 'post'
  },

  onlineList: {
    redisHost: process.env.REDIS_ONLINELIST_PORT_6379_TCP_ADDR || 'localhost',
    redisPort: +process.env.REDIS_ONLINELIST_PORT_6379_TCP_PORT || 6379,
    maxSize: +process.env.ONLINE_LIST_SIZE || 20,
    invisibleUsernameRegExp: process.env.hasOwnProperty('ONLINE_LIST_INVISIBLE_MATCH')
      ? new RegExp(process.env.ONLINE_LIST_INVISIBLE_MATCH)
      : null
  },

  pushApi: {
    // Redis and its queues
    redisHost: process.env.REDIS_PUSHAPI_PORT_6379_TCP_ADDR || 'localhost',
    redisPort: +process.env.REDIS_PUSHAPI_PORT_6379_TCP_PORT || 6379,
    tokensPrefix: [unversionedApi, 'push-tokens', 'data-v2'].join(':'),
    notificationsPrefix: [unversionedApi, 'push-notifications'].join(':'),

    // When sending push notifications, sender cli will:
    //  read up to readAhead tasks from redis
    //    (this means it will remove them from redis for
    //     processing in this instance)
    //
    //  each task can have multiple tokens which are individual
    //  push notifications transported in parallel. Only about
    //  parallelSends can be running at any given moment.
    cli: {
      readAhead: process.env.BATCH_SIZE || 10,
      parallelSends: process.env.BATCH_SIZE || 10
    },

    // Apple related
    apn: {
      // connection
      cert: process.env.APN_CERT_FILEPATH ||
        path.join(__dirname, 'tests/push-api/cert.pem'),
      key: process.env.APN_KEY_FILEPATH ||
        path.join(__dirname, 'tests/push-api/key.pem'),
      maxConnections: 2,
      // push messages
      defaultAlert: '\uD83D\uDCE7 \u2709 You have a new message',
      expiry: 3600,
      badge: 1,
      sound: 'ping.aiff'
    },

    // GCM related
    gcm: {
      apiKey: process.env.GCM_API_KEY,
      icon: 'app_icon', // Fill in resource ID
      defaultTitle: 'You have a new message'
    }
  }
};

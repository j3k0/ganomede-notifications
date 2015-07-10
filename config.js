var path = require('path');
var pkg = require("./package.json");

var unversionedApi = removeServiceVersion(pkg.api);

function removeServiceVersion (name) {
  var pos = name.search(/\/v\d+/);
  return -1 == pos
    ? name
    : name.slice(0, pos);
}

module.exports = {
  port: +process.env.PORT || 8000,
  routePrefix: process.env.ROUTE_PREFIX || pkg.api,
  longPollDurationMillis: 30000,
  removeServiceVersion: removeServiceVersion,
  debug: process.env.NODE_ENV !== 'production',

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
    maxSize: +process.env.ONLINE_LIST_SIZE || 20
  },

  pushApi: {
    redisHost: process.env.REDIS_PUSHAPI_PORT_6379_TCP_ADDR || 'localhost',
    redisPort: +process.env.REDIS_PUSHAPI_PORT_6379_TCP_PORT || 6379,
    tokensPrefix: [unversionedApi, 'push-tokens'].join(':'),
    notificationsPrefix: [unversionedApi, 'push-notifications'].join(':'),
    apn: {
      // connection
      cert: process.env.APN_CERT_FILEPATH ||
        path.join(__dirname, 'tests/push-api/cert.pem'),
      key: process.env.APN_KEY_FILEPATH ||
        path.join(__dirname, 'tests/push-api/key.pem'),
      // push messages
      expiry: Math.floor(Date.now() / 1000) + 3600,
      badge: 3,
      sound: 'ping.aiff'
    }
  }
};

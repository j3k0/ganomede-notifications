var pkg = require("./package.json");

module.exports = {
  port: +process.env.PORT || 8000,
  routePrefix: process.env.ROUTE_PREFIX || pkg.api,
  longPollDurationMillis: 30000,

  authdb: {
    host: process.env.REDIS_AUTH_PORT_6379_TCP_ADDR || 'localhost',
    port: +process.env.REDIS_AUTH_PORT_6379_TCP_PORT || 6379
  },

  redis: {
    host: process.env.REDIS_NOTIFICATIONS_PORT_6379_TCP_ADDR || 'localhost',
    port: +process.env.REDIS_NOTIFICATIONS_PORT_6379_TCP_PORT || 6379,
    queueSize: +process.env.MESSAGE_QUEUE_SIZE || 50,
    onlineSize: +process.env.ONLINE_LIST_SIZE || 20,
    channel: 'post'
  }
};

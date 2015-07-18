# Sending push notifications from redis queue.

# Use New Relic if LICENSE_KEY has been specified.
if process.env.NEW_RELIC_LICENSE_KEY
  if !process.env.NEW_RELIC_APP_NAME
    process.env.NEW_RELIC_APP_NAME = "push-worker/v1"
  require 'newrelic'

stream = require 'stream'
redis = require 'redis'
config = require '../../config'
Token = require './token'
TokenStorage = require './token-storage'
Sender = require './sender'
Queue = require './queue'
log = (require '../log').child({SenderCli: true})

# How many connections to Apple
# (not sure if this is working with APN atm)
CONCURRENT_CONNECTIONS = 4

debug = if !config.debug then () -> else () ->
  console.log.apply(console, arguments)

class Producer extends stream.Readable
  constructor: (@queue, concurrency=CONCURRENT_CONNECTIONS) ->
    super({objectMode: true, highWaterMark: concurrency})

  _read: (size) ->
    @queue.get (err, task) =>
      if (err)
        log.error 'Failed to retrieve task', err
        @emit('error', err)
        return @push(null)

      # If no tokens, skip notification, and call _read() manually
      # (required since push() must be called for every _read.)
      if (task && task.tokens.length == 0)
        log.warn 'Found no tokens for sending notification, skipping',
          task.notification
        return process.nextTick(@_read.bind(@))

      if task
        debug('read %d', task.notification.id)
      # else
      #  log.info 'Queue is empty'

      @push(task)

class Consumer extends stream.Writable
  constructor: (@sender, concurrency=CONCURRENT_CONNECTIONS) ->
    super({objectMode: true})

    @state =
      nMax: concurrency
      nWaiting: 0
      readyFunctions: []

    connection = @sender.senders[Token.APN].connection
    connection.on 'transmitted', Consumer.onTransmitted.bind(@)

  # The idea is that we ready for more, when `transmitted` event occurs
  # N times (where N is number of tokens for each task).
  # That way Producer won't buffer too many of notifications and "too many"
  # is adjustable by concurrency inside Producer ctor.
  taskAdded: (nTokens, readyFn) ->
    @state.nWaiting += nTokens
    debug('state %j', @state)

    if @canAddMoreTasks()
      readyFn()
    else
      @state.readyFunctions.push(readyFn)

  canAddMoreTasks: () ->
    return @state.nWaiting < @state.nMax

  @onTransmitted = (notification, device) ->
    @state.nWaiting -= 1
    if @canAddMoreTasks()
      readyFn = @state.readyFunctions.shift()
      if readyFn
        readyFn()

  _write: (task, encoding, readyForMore) ->
    debug('written %d', task.notification.id)
    @taskAdded(task.tokens.length, readyForMore)
    @sender.send task, () ->

main = (testing) ->
  client = redis.createClient(
    config.pushApi.redisPort, config.pushApi.redisHost
  )

  storage = new TokenStorage(client)
  queue = new Queue(client, storage)

  senders = {}
  senders[Token.APN] = apnSender = new Sender.ApnSender(
    cert: config.pushApi.apn.cert
    key: config.pushApi.apn.key
    buffersNotifications: false
    maxConnections: CONCURRENT_CONNECTIONS
  )
  sender = new Sender(senders)

  producer = new Producer(queue)
  consumer = new Consumer(sender)

  producer.on 'end', () ->
    # log.info 'producer end'
    client.quit()

  producer.on 'error', (err) ->
    log.info 'producer error', err

  consumer.on 'finish', () ->
    # log.info 'consumer end'
    apnSender.close()
    process.exit()

  consumer.on 'error', (err) ->
    log.info 'consumer error', err

  # Start callbacking
  start = (err) ->
    if (err)
      log.info('START CALLED WITH ERROR\n', err)
      return process.exit(1)

    producer.pipe(consumer)

  # Dump 100 notifications to redis and token for user.
  populateRedis = (callback) ->
    objects = [1..100].map (i) -> JSON.stringify(
      to: 'alice'
      id: i
      push: {
        app: 'app'
        title: ['test']
        message: ['test-msg']
      }
    )

    token = Token.fromPayload(
      username: 'alice'
      app: 'app'
      type: 'apn'
      value: process.env.TEST_APN_TOKEN
    )

    args = [config.pushApi.notificationsPrefix].concat(objects)
    multi = client.multi()
    multi.flushdb()
    multi.lpush.apply(multi, args)
    multi.exec (err) ->
      if (err)
        return callback(err)

      storage.add token, (err, added) ->
        if (err)
          return callback(err)

        if (!added)
          return callback(new Error('No token added'))

        callback()

  if testing then populateRedis(start) else start()

unless module.parent
  main(process.env.hasOwnProperty('TEST_APN_TOKEN'))

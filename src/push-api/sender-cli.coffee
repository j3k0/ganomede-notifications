# Sending push notifications from redis queue.

# Use New Relic if LICENSE_KEY has been specified.
if process.env.NEW_RELIC_LICENSE_KEY
  if !process.env.NEW_RELIC_APP_NAME
    process.env.NEW_RELIC_APP_NAME = "push-worker/v1"
  require 'newrelic'

vasync = require 'vasync'
stream = require 'stream'
redis = require 'redis'
config = require '../../config'
Token = require './token'
TokenStorage = require './token-storage'
Sender = require './sender'
Queue = require './queue'
log = (require '../log').child(SenderCli:true)

debug = if !config.debug then () -> else () ->
  log.debug.apply(log, arguments)

class Producer extends stream.Readable
  constructor: (@queue) ->
    super({objectMode: true, highWaterMark: config.pushApi.cli.readAhead})

  _getTask: (callback) ->
    @queue.get (err, task) =>
      if (err)
        log.error({err: err}, 'Failed to retrieve task')
        return callback(err, null)

      # If no tokens, skip notification, and _getTask() again for a new item.
      if (task && task.tokens.length == 0)
        log.info({to: task.notification.to}, '[skip] No tokens for user')
        return process.nextTick(@_getTask.bind(@, callback))

      if task
        debug('read', id:task.notification.id)
      else
        debug('queue is empty')

      callback(null, task || null)

  _read: (size) ->
    @_getTask (err, task) =>
      if (err)
        @emit('erorr', err)

      @push(task)

class Consumer extends stream.Writable
  constructor: (@sender) ->
    super({objectMode: true, highWaterMark: config.pushApi.cli.parallelSends})

    @state =
      queued: 0
      finished: 0
      maxDiff: config.pushApi.cli.parallelSends
      processedCallbacks: []

    @sender.on Sender.events.PROCESSED, (senderType, notifId, token) =>
      @state.finished += 1
      debug("#{senderType} processed #{notifId} for #{token}", @state)

      canQueueMore = @state.queued - @state.finished <= @state.maxDiff
      if canQueueMore
        debug('can queue more', @state)
        fn = @state.processedCallbacks.pop()
        if fn
          fn()

    # @sender.on Sender.events.SUCCESS, (senderType, info) ->
    #   debug("#{senderType} succeeded", info)

    @sender.on Sender.events.FAILURE, (senderType, err, notifId, token) ->
      log.error({err: err},
        "#{senderType} failed to send #{notifId} for #{token}")

  _write: (task, encoding, processed) ->
    @state.queued += task.tokens.length
    @state.processedCallbacks.push(processed)
    debug('written', id:task.notification.id, @state)
    @sender.send task

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
    maxConnections: config.pushApi.apn.maxConnections
  )

  senders[Token.GCM] = gcmSender = new Sender.GcmSender(
    config.pushApi.gcm.apiKey
  )

  sender = new Sender(senders)
  producer = new Producer(queue)
  consumer = new Consumer(sender)

  # Keep track of closed sockets.
  quitters =
    redis: false
    apn: false

  # redis queue is empty
  producer.on 'end', () ->
    client.quit()
    client.once 'end', () ->
      quitters.redis = true

  # all the tasks are enqueued to be sent or sent
  consumer.on 'finish', () ->
    # Redis usually shuts down nicely, but APN might need some time,
    # give it that, and force exit if it won't play nicely.
    forceExitTimeout = setTimeout () ->
      debug('forced exit', quitters)
      process.exit(0)
    , 2000

    tryToExit = () ->
      debug('trying to exit', quitters)
      if (quitters.redis && quitters.apn)
        return clearTimeout(forceExitTimeout)

    apnSender.close () ->
      quitters.apn = true
      tryToExit()

  # Start callbacking
  start = (err) ->
    if (err)
      log.error({err: err}, 'start() called with error')
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

    tokenGcm = Token.fromPayload(
      username: 'alice'
      app: 'app'
      type: 'gcm'
      value: process.env.TEST_GCM_TOKEN
    )

    args = [config.pushApi.notificationsPrefix].concat(objects)
    multi = client.multi()
    multi.flushdb()
    multi.lpush.apply(multi, args)
    multi.exec (err) ->
      if (err)
        return callback(err)

      tokensToAdd = [token, tokenGcm].map (t) -> storage.add.bind(storage, t)

      vasync.parallel {funcs: tokensToAdd}, (err, results) ->
        if (err)
          return callback(err)

        if (!results.successes.every (ret) -> ret == true)
          return callback(new Error('Not every token was added'))

        callback()

  if testing then populateRedis(start) else start()

unless module.parent
  main(process.env.hasOwnProperty('TEST_APN_TOKEN'))

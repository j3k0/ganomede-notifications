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
log = (require '../log').child(SenderCli:true)

debug = if !config.debug then () -> else () ->
  # console.log.apply(console, arguments)
  log.debug.apply(log, arguments)

class Producer extends stream.Readable
  constructor: (@queue) ->
    super({objectMode: true, highWaterMark: config.pushApi.cliReadAhead})

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
        debug 'read', id:task.notification.id
      # else
      #  log.info 'Queue is empty'

      @push(task)

class Consumer extends stream.Writable
  constructor: (@sender) ->
    super({objectMode: true})

    @state =
      nMax: config.pushApi.cliReadAhead
      nWaiting: 0
      readyFunctions: []
      finishCallback: null

    connection = @sender.senders[Token.APN].connection
    connection.on 'transmitted', @onTransmitted.bind(@)

  # The idea is that we ready for more, when `transmitted` event occurs
  # N times (where N is number of tokens for each task).
  # That way Producer won't buffer too many of notifications and "too many"
  # is adjustable by config.pushApi.cliReadAhead.
  taskAdded: (nTokens, readyFn) ->
    @state.nWaiting += nTokens
    debug 'taskAdded', state:@state

    if @canAddMoreTasks()
      readyFn()
    else
      @state.readyFunctions.push(readyFn)

  canAddMoreTasks: () ->
    return @state.nWaiting < @state.nMax

  onTransmitted: (notification, device) ->
    debug 'transmitted', notification.payload.id

    @state.nWaiting -= 1
    if @canAddMoreTasks()
      readyFn = @state.readyFunctions.shift()
      if readyFn
        readyFn()

    # When no more tasks will be added, finishCallback will be set,
    # call it when everything in the queue is transmitted.
    if @state.finishCallback && (@state.nWaiting == 0)
      @state.finishCallback()

  _write: (task, encoding, readyForMore) ->
    debug 'written', id:task.notification.id
    @sender.send task
    @taskAdded(task.tokens.length, readyForMore)

  # Call when no more tasks will be added
  finishUp: (callback) ->
    @state.finishCallback = callback
    if @state.nWaiting == 0
      callback()

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
  sender = new Sender(senders)

  producer = new Producer(queue)
  consumer = new Consumer(sender)

  producer.on 'end', () ->
    client.quit()

  producer.on 'error', (err) ->
    log.info 'producer error', err

  consumer.on 'finish', () ->
    debug 'finishing up with', consumer.state
    apnSender.close()

    consumer.finishUp () ->
      debug 'finished up with', consumer.state

      # Sometimes `apn` does close connection, sometimes it doesn't.
      # Give it a moment before we force it.
      exit = () ->
        debug('forced exit')
        process.exit(0)

      setTimeout(exit, 500)

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

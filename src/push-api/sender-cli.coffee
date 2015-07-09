# Sending push notifications from redis queue.

events = require 'events'
redis = require 'redis'
config = require '../../config'
Token = require './token'
TokenStorage = require './token-storage'
Sender = require './sender'
log = (require '../log').child({SenderCli: true})

class SenderCli extends events.EventEmitter
  constructor: (@sender) ->
    unless @sender instanceof Sender
      throw new Error('SenderRequired')

    onTask = @onTask.bind(@)
    processNextTask = @sender.nextTask.bind(@sender, onTask)
    @tick = process.nextTick.bind(process, processNextTask)

  done: (err) ->
    @emit(SenderCli.events.DONE, err)

  onTask: (err, task) ->
    if (err)
      log.error('onTask() called with error, exiting')
      return @done(err)

    if (!task)
      log.info('onTask() recieved null task, queue is empty')
      return @done(null)

    @sender.send task, (err, results) =>
      if (err)
        log.error 'Sender.send() failed to send notification',
          err: err,
          task: task
        return @done(err)

      log.info 'Notifications sent', task
      @tick()

SenderCli.events =
  DONE: 'done'

main = (testing) ->
  client = redis.createClient(
    config.pushApi.redisPort, config.pushApi.redisHost
  )

  senders = {}
  senders[Token.APN] = new Sender.ApnSender(
    cert: config.pushApi.apn.cert
    key: config.pushApi.apn.key
  )

  storage = new TokenStorage(client)
  sender = new Sender(client, storage, senders)
  cli = new SenderCli(sender)

  onDone = (err) ->
    if (err)
      log.error 'Done with error', err
    else
      log.info 'Done successfully'

    for own type, sender of senders
      sender.close()

    client.quit (redisErr, reply) ->
      if err
        exitCode = 1
      else if redisErr || reply != 'OK'
        exitCode = 2
      else
        exitCode = 0

      log.info 'Redis closed with', {err: err, reply: reply}
      process.exit(exitCode)

  test = () ->
    log.info 'Testing…'

    token = Token.fromPayload(
      username: 'alice'
      app: 'game'
      type: 'apn'
      value: process.env.TEST_APN_TOKEN
    )

    notification =
      from: 'game',
      to: 'alice',
      type: 'invitation-created',
      data: {},
      timestamp: 1436269938903,
      id: 1

    (require 'vasync').parallel
      funcs: [
        storage.add.bind(storage, token)
        sender.addNotification.bind(sender, notification)
      ]
    , (err, results) ->
      if err then onDone(err) else start()

  start = () ->
    cli.once(SenderCli.events.DONE, onDone)
    cli.tick()

  if testing then test() else start()

module.exports = SenderCli

unless module.parent
  main(process.env.hasOwnProperty('TEST_APN_TOKEN'))

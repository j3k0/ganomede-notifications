apn = require 'apn'
gcm = require 'node-gcm'
events = require 'events'
vasync = require 'vasync'
Token = require './token'
config = require '../../config'
log = (require '../log').child(sender:true)

# TODO
# listen for errors:
# https://github.com/argon/node-apn/blob/master/doc/connection.markdown
class ApnSender
  constructor: (options) ->
    options.production = options.production || !config.debug
    @connection = new apn.Connection(options)
    @log = log.child apn:true

  send: (notification, tokens) ->
    @log.info {
      id: notification.payload.id,
      to: notification.payload.to
    }, "sending APN"
    devices = tokens.map (token) -> new apn.Device(token.data())
    @connection.pushNotification(notification, devices)

  close: (cb) ->
    @connection.once('disconnected', cb)
    @connection.shutdown()

class GcmSender extends events.EventEmitter
  constructor: (apiKey) ->
    super()
    @gcm = new gcm.Sender(apiKey)
    @log = log.child({gcm: true})

  _send: (message, ids) ->
    @gcm.sendNoRetry message,
      {registrationTokens: ids},
      (err, result) =>
        # Unlike APN sender, we need to manually emit N times for each token.
        notifId = message.params.data.notificationId
        for token in ids
          if err
            @emit(Sender.events.FAILURE, {httpCode: err}, notifId, token)
          else
            @emit(Sender.events.SUCCESS, notifId, token)

  send: (gcmMessage, tokens) ->
    @log.info {
      id: gcmMessage.params.data.notificationId
      to: gcmMessage.params.data.notificationTo
    }, "sending GCM"
    registrationIds = tokens.map (token) -> token.data()
    @_send(gcmMessage, registrationIds)

class Sender extends events.EventEmitter
  constructor: (@senders={}) ->
    super()

    # APN events
    # (no way to know about success)
    @senders[Token.APN].connection.on 'transmitted', (notification, device) =>
      @emit(Sender.events.PROCESSED, Token.APN, notification.payload.id, device)

    @senders[Token.APN].connection.on 'transmissionError', (code, n, device) =>
      @emit(Sender.events.FAILURE, Token.APN, {code}, n.payload.id, device)

    # GCM Events
    # (since it is POST, we can reliably know if notification was accpeted)
    @senders[Token.GCM].on Sender.events.SUCCESS, (notifId, token) =>
      @emit(Sender.events.PROCESSED, Token.GCM, notifId, token)
      @emit(Sender.events.SUCCESS, Token.GCM, notifId, token)

    @senders[Token.GCM].on Sender.events.FAILURE, (error, notifId, token) =>
      @emit(Sender.events.PROCESSED, Token.GCM, notifId, token)
      @emit(Sender.events.FAILURE, Token.GCM, error, notifId, token)

  # Sends push notification from task.notification for each one of task.tokens.
  send: (task) ->
    # Group tokens by type
    groupedTokens = {}
    task.tokens.forEach (token) ->
      groupedTokens[token.type] = groupedTokens[token.type] || []
      groupedTokens[token.type].push(token)

    # For each token group, invoke appropriate sender
    sendFunctions = []
    for own type, tokens of groupedTokens
      sender = @senders[type]
      if !sender
        throw new Error("No sender specified for #{type} token type")

      fn = sender.send.bind(sender, task.convert(type), tokens)
      sendFunctions.push(fn)

    # Exec those functions
    sendFunctions.forEach (fn) -> fn()

  @events: {
    # notification processed somehow
    # cb(senderType, notificationId, token)
    PROCESSED: 'processed'
    # notification succeeded
    # cb(senderType, notificationId, token)
    SUCCESS: 'sent'
    # notification failed
    # cb(senderType, error, notificationId, token)
    FAILURE: 'failed'
  }

Sender.GcmSender = GcmSender
Sender.ApnSender = ApnSender
module.exports = Sender

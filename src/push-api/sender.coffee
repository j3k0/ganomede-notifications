apn = require 'apn'
vasync = require 'vasync'
config = require '../../config'

# TODO
# listen for errors:
# https://github.com/argon/node-apn/blob/master/doc/connection.markdown
class ApnSender
  constructor: (options) ->
    options.production = options.production || !config.debug
    @connection = new apn.Connection(options)

  # TODO
  # errors?
  send: (notification, tokens) ->
    devices = tokens.map (token) -> new apn.Device(token.data())
    @connection.pushNotification(notification, devices)

  close: () ->
    @connection.shutdown()

class Sender
  constructor: (@senders={}) ->

  # Sends push notification from task.notification for each one of task.tokens.
  send: (task, callback) ->
    # Group tokens by type
    grouppedTokens = {}
    task.tokens.forEach (token) ->
      grouppedTokens[token.type] = grouppedTokens[token.type] || []
      grouppedTokens[token.type].push(token)

    # For each token group, invoke appropriate sender
    sendFunctions = []
    for own type, tokens of grouppedTokens
      sender = @senders[type]
      if !sender
        throw new Error("No sender specified for #{type} token type")

      fn = sender.send.bind(sender, task.convert(type), tokens)
      sendFunctions.push(fn)

    # Exec those functions
    vasync.parallel({funcs: sendFunctions}, callback)

Sender.ApnSender = ApnSender
module.exports = Sender

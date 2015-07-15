# "push": {
#   "type": "someone_loves_someone",
#   "title": [ "Love {1}", "bob" ],
#   "message": [ "Did you know? {1} loves {2}", "alice", "bob" ],
# }
#
# Should allow to fill APN:
#
# title with title[0] with arguments inserted
# title-key with #{type}_title
# title-args with title[1..n]
# body with message[0] with arguments inserted
# loc-key with #{type}_message
# loc-args with message[1..n]

util = require 'util'
apn = require 'apn'
Token = require './token'
config = require '../../config'
log = require '../log'

class Task
  constructor: (@notification, @tokens) ->
    unless @notification
      throw new Error('NotificationRequired')

    unless @tokens
      throw new Error('TokensRequired')

    # Store result of converting @notification to provider format
    @converted = {}

  convert: (type) ->
    unless @converted.hasOwnProperty(type)
      unless Task.converters.hasOwnProperty(type)
        throw new Error("#{type} convertion not supported")

      @converted[type] = Task.converters[type](@notification)

    return @converted[type]

Task.converters = {}

Task.converters[Token.APN] = (notification) ->
  note = new apn.Notification()

  note.expiry = Math.floor(Date.now() / 1000) + config.pushApi.apn.expiry
  note.badge = config.pushApi.apn.badge
  note.sound = config.pushApi.apn.sound
  note.payload = notification
  note.alert = Task.converters[Token.APN].alert(notification.push)

  return note

Task.converters[Token.APN].alert = (push) ->
  localized = Array.isArray(push.title) && Array.isArray(push.message)
  if localized
    return {
      'title-loc-key': push.title[0]
      'title-loc-args': push.title.slice(1)
      'loc-key': push.message[0]
      'loc-args': push.message.slice(1)
    }
  else
    # Not sure what notification.alert should be while converting to APN.
    log.warn 'Not sure what apnNotification.alert should be given push', push
    return config.pushApi.apn.defaultAlert

module.exports = Task

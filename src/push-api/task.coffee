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

clone = (obj) -> JSON.parse(JSON.stringify(obj))

Task.converters[Token.APN] = (notification) ->
  note = new apn.Notification()

  note.expiry = Math.floor(Date.now() / 1000) + config.pushApi.apn.expiry
  note.badge = config.pushApi.apn.badge
  note.sound = config.pushApi.apn.sound
  note.payload = clone(notification)
  note.alert = Task.converters[Token.APN].alert(notification.push)

  # Make sure not to expose API_SECRET!
  if notification.secret
    delete note.payload.secret
  delete note.payload.push

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

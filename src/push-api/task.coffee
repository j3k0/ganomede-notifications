apn = require 'apn'
gcm = require 'node-gcm'
lodash = require 'lodash'
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
  note.payload =
    id: notification.id
    type: notification.type
    from: notification.from
    to: notification.to
    timestamp: notification.timestamp
    data: notification.data
    push: notification.push
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

Task.converters[Token.GCM] = (notification) ->
  return new gcm.Message({
    data:
      json: JSON.stringify(notification)
      notificationId: notification.id # for easier debug prints
    notification: Task.converters[Token.GCM].notification(notification.push)
  })

Task.converters[Token.GCM].notification = (push) ->
  unless Array.isArray(push.title) && Array.isArray(push.message)
    log.warn 'Not sure what gcmNote.notification should be for push', push
    return lodash.extend {tag: push.app}, config.pushApi.gcm.defaultNotification

  return {
    tag: push.app
    icon: config.pushApi.gcm.icon
    title_loc_key: push.title[0]
    title_loc_args: push.title.slice(1)
    body_loc_key: push.message[0]
    body_loc_args: push.message.slice(1)
  }

module.exports = Task

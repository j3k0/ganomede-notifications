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

Token = require './token'

class Task
  constructor: (@notification, @tokens) ->
    unless @notification
      throw new Error('NotificationRequired')

    unless @tokens
      throw new Error('TokensRequired')

    # Store result of converting @notification to provider format
    @converted = {}

  convertPayload: (type) ->
    # Only need to convert some certain type of messages
    push = @notification.push
    needsConverting = push && Array.isArray(push.message) &&
      Array.isArray(push.title) && push.hasOwnProperty('type')

    unless needsConverting
      return @notification

    unless @converted.hasOwnProperty(type)
      unless Task.converters.hasOwnProperty(type)
        throw new Error("#{type} convertion not supported")

      @converted[type] = Task.converters[type](push)

    return @converted[type]

Task.converters = {}

Task.converters[Token.APN] = (push) ->
  return {
    'title': push.title[0]
    'title-key': "#{push.type}_title"
    'title-args': push.title.slice(1)
    'body': push.message[0]
    'loc-key': "#{push.type}_message"
    'loc-args': push.message.slice(1)
  }

module.exports = Task

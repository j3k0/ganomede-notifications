class PushTranslator
  constructor: () ->

  # callback(null, translated)
  # error is always null!
  process: (notification, callback) ->
    setImmediate(callback, null, notification)

module.exports = PushTranslator

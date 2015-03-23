class LP
  constructor: (onTrigger, onTimeout) ->
    @trigger = onTrigger
    @timeout = onTimeout
    @timeoutId = null

  start: (millis) ->
    @stop()
    @timeoutId = setTimeout(@timeout.bind(@), millis)

  stop: () ->
    if @timeoutId
      clearTimeout(@timeoutId)

    @timeoutId = null

class LongPoll
  constructor: (timeoutMillis) ->
    @millis = timeoutMillis
    @store = {}

  clear: (key) ->
    if @store.hasOwnProperty(key)
      lp = @store[key]
      delete @store[key]
      lp.stop()

  clearBefore: (key, cb) ->
    clear = @clear.bind(@, key)
    return () ->
      clear()
      cb()

  add: (key, onTrigger, onTimeout) ->
    if (@store.hasOwnProperty(key))
      @store[key].stop()
      setTimeout(@store[key].timeout.bind(@store[key]), @millis / 2)

    triggerFn = @clearBefore(key, onTrigger.bind(null, key))
    timeoutFn = @clearBefore(key, onTimeout.bind(null, key))
    lp = new LP(triggerFn, timeoutFn)

    @store[key] = lp
    lp.start(@millis)

  trigger: (key) ->
    if (@store.hasOwnProperty(key))
      @store[key].trigger()

module.exports = LongPoll

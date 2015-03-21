expect = require 'expect.js'
LongPoll = require '../../src/notifications-api/long-poll'

TRIGGERED = 'triggered'
TIMED_OUT = 'timedOut'
MILLIS = 10

describe 'LongPoll', () ->
  lp = new LongPoll(MILLIS)
  theKey = 'key'

  onTrigger = (cb) ->
    (key) -> cb?(TRIGGERED, key)

  onTimeout = (cb) ->
    (key) -> cb?(TIMED_OUT, key)

  wait = (millis, fn) -> setTimeout(fn, millis)

  it 'triggers', (done) ->
    callDone = (reason, key) ->
      expect(reason).to.be(TRIGGERED)
      expect(key).to.be(theKey)
      done()

    lp.add theKey, onTrigger(callDone), onTimeout(callDone)
    lp.trigger(theKey)

  it 'times out', (done) ->
    callDone = (reason, key) ->
      expect(reason).to.be(TIMED_OUT)
      expect(key).to.be(theKey)
      done()

    lp.add theKey, onTrigger(callDone), onTimeout(callDone)

import expect from 'expect.js';
import LongPoll from '../../src/notifications-api/long-poll';
import {describe, it} from 'mocha';

const TRIGGERED = 'triggered';
const TIMED_OUT = 'timedOut';
const MILLIS = 10;

describe('LongPoll', function() {
  const lp = new LongPoll(MILLIS);
  const theKey = 'key';

  const onTrigger = cb => key => { typeof cb === 'function' && cb(TRIGGERED, key) };
  const onTimeout = cb => key => { typeof cb === 'function' && cb(TIMED_OUT, key) };

  // const wait = (millis, fn) => setTimeout(fn, millis);

  it('triggers', function(done) {
    const callDone = function(reason, key) {
      expect(reason).to.be(TRIGGERED);
      expect(key).to.be(theKey);
      return done();
    };

    lp.add(theKey, onTrigger(callDone), onTimeout(callDone));
    return lp.trigger(theKey);
  });

  return it('times out', function(done) {
    const callDone = function(reason, key) {
      expect(reason).to.be(TIMED_OUT);
      expect(key).to.be(theKey);
      return done();
    };

    return lp.add(theKey, onTrigger(callDone), onTimeout(callDone));
  });
});

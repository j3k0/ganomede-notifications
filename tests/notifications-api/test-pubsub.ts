/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import fakeRedis from 'fakeredis';
import expect from 'expect.js';
import PubSub from '../../src/notifications-api/pubsub';
import config from '../../config';
import {after, before, describe, it} from 'mocha';

describe('PubSub', function() {
  const redisId = '' + Math.random() + '' + Math.random();
  const redis = fakeRedis.createClient(redisId);
  const redisSub = fakeRedis.createClient(redisId);

  const pubsub = new PubSub({
    publisher: redis,
    subscriber: redisSub,
    channel: config.redis.channel
  });

  before(done => { redis.flushdb(done); });
  after(done => { pubsub.quit(done); });

  it('Subscribes to messages and able to recieve them', function(done) {
    let n = 0;
    const callDone = function() {
      ++n;
      if (n === 2) {
        done();
      }
    };

    const onMessage = function(channel, data) {
      expect(channel).to.be(config.redis.channel);
      expect(data).to.be('some-data');
      callDone();
    };

    pubsub.subscribe(onMessage, () => { pubsub.publish('some-data', function(err, nRecievers) {
      expect(err).to.be(null);
      expect(nRecievers).to.be(1);
      callDone();
    }); });
  });
});

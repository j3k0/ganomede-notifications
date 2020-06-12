import * as fakeredis from 'fakeredis';
import expect from 'expect.js';
import Queue from '../../src/push-api/queue';
import Token from '../../src/push-api/token';
import TokenStorage from '../../src/push-api/token-storage';
import config from '../../config';
import samples from './samples';
import log from '../../src/log';
import {beforeEach, describe, it} from 'mocha';

describe('Queue', function() {
  const redis = fakeredis.createClient();
  const tokenStorage = new TokenStorage(redis);

  const notification1 = samples.notification();
  const notification2 = samples.notification({}, 'reciever-with-no-tokens');

  beforeEach(done => {
    redis.flushdb(() => {
      tokenStorage.add(Token.fromPayload(samples.tokenData()), done);
    }); });

  describe('#add()', function() {
    const queue = new Queue(redis, tokenStorage);

    it('adds push notification to the redis list', done => { queue.add(notification1, function(err, newLength) {
      expect(err).to.be(null);
      expect(newLength).to.be(1);
      done();
    }); });

    it('adds push notification to the head of the list', done => {
      queue.add(notification1, function(_err, _newLength) {
        queue.add(notification2, function(err, newLength) {
          expect(err).to.be(null);
          expect(newLength).to.be(2);

          redis.lrange(config.pushApi.notificationsPrefix, 0, -1, function(err, list) {
            expect(err).to.be(null);
            expect(list).to.be.an(Array);

            expect(list.map(item => JSON.parse(item))).to.eql(
              [notification2, notification1]
            );

            done();
          });
        });
      });
    });
  });

  describe('#get()', function() {
    const queue = new Queue(redis, tokenStorage);
    it(`returns task with notification and push token when there are messages in the list`,
    done => {
    queue.add(notification1, function(_err, newLength) {
      expect(newLength).to.be(1);
      queue.get(function(err, task) {
        expect(err).to.be(null);
        log.info({task}, 'task');
        expect(task).to.be.an(Object);
        expect(task?.notification).to.be.an(Object);
        expect(task?.tokens).to.be.an(Array);
        expect(task?.tokens).to.have.length(1);
        expect(task?.tokens[0]).to.be.a(Token);
        done();
      });
    }); });

    it(`when no tokens found for notification receiver, returns task with 0 tokens`,
    done => {
    queue.add(notification2, function(_err, newLength) {
      queue.get(function(err, task) {
        expect(err).to.be(null);
        expect(task?.tokens).to.be.an(Array);
        expect(task?.tokens).to.have.length(0);
        done();
      });
    }); });

    it('returns null when no items left in the list', done => { queue.get(function(err, task) {
      expect(err).to.be(null);
      expect(task).to.be(null);
      done();
    }); });
  });
});

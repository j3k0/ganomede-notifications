import * as vasync from 'vasync';
import expect from 'expect.js';
import supertest from 'supertest';
import * as fakeRedis from 'fakeredis';
import * as sinon from 'sinon';
import * as restify from 'restify';
import fakeAuthdb from '../fake-authdb';
import notificationsApi from "../../src/notifications-api";
import PubSub from "../../src/notifications-api/pubsub";
import Queue from "../../src/notifications-api/queue";
import LongPoll from "../../src/notifications-api/long-poll";
import serverMod from '../../src/server';
import config from '../../config';
import samples from './sample-data';
import helpers from './helpers';
import {afterEach, beforeEach, describe, it} from 'mocha';

const INVALID_SECRET = 'INVALID_SECRET';
const API_SECRET = config.secret;
const LP_MILLIS = 300; // if this is too low, we won't be able to put message in redis
// in time for testing long poll triggering on new message
const NEW_MESSAGE_ID = 3;

const endpoint = (path?) => `/${config.routePrefix}${path || ''}`;

const timeout = (millis, fn) => setTimeout(fn, millis);

describe("Notifications API", function() {
  const redisId = '' + Math.random() + '' + Math.random();
  let server:restify.Server|null = null;
  let redis = fakeRedis.createClient(redisId);
  let go:any = null;
  let authdb = fakeAuthdb.createClient();
  let queue = new Queue(redis, {maxSize: config.redis.queueSize});
  let longPoll = new LongPoll(LP_MILLIS);
  const addPushNotification = sinon.spy();
  let pubsub = new PubSub({
    publisher: redis,
    subscriber: fakeRedis.createClient(redisId),
    channel: config.redis.channel
  });

  beforeEach(function(done) {
    const redisId = '' + Math.random() + '' + Math.random();
    redis = fakeRedis.createClient(redisId);
    pubsub = new PubSub({
      publisher: redis,
      subscriber: fakeRedis.createClient(redisId),
      channel: config.redis.channel
    });
    authdb = fakeAuthdb.createClient();
    longPoll = new LongPoll(LP_MILLIS);
    server = serverMod.createServer();
    go = () => supertest(server);
    for (let username of Object.keys(samples.users || {})) {
      const data = samples.users[username];
      authdb.addAccount(data.token, data.account);
    }

    const api = notificationsApi({
      authdbClient: authdb,
      pubsub,
      queue,
      longPoll,
      addPushNotification
    });

    api(endpoint(), server);

    vasync.parallel({
      funcs: [
        cb => { server?.listen(1337 + (Math.random() * 30000)|0, cb) },
        cb => { redis.flushdb(cb); }
      ]
    }, done);
  });
  afterEach(done => { vasync.parallel({
    funcs: [
      pubsub.quit.bind(pubsub),
      server!.close.bind(server)
    ]
  }, done); });

  describe('POST /messages', function() {
    it('creates message and replies with its ID and timestamp', done => { go()
      .post(endpoint('/messages'))
      .send(samples.notification(API_SECRET))
      .expect(200)
      .end(function(err, res) {
        expect(err).to.be(null);
        expect(res.body).to.be.an(Object);
        expect(res.body.id).to.be(1);
        expect(res.body).to.have.property('timestamp');
        done();
    }); });

    it(`when adding message with \`.push\` object, calls options.addPushNotification`,
    function(done) {
      const {
        username
      } = samples.users.pushNotified.account;
      const push = {message: `This is push message for ${username}, nice!`};
      const notification = samples.notification(API_SECRET, username, push);

      go()
        .post(endpoint('/messages'))
        .send(notification)
        .expect(200)
        .end(function(err, res) {
          expect(err).to.be(null);
          // Update sent notification to a state that we expect to be saved as
          // and compare it to what addPushNotification() was called with.
          delete notification.secret;
          notification.id = res.body.id;
          notification.timestamp = res.body.timestamp;

          expect(addPushNotification.calledOnce).to.be(true);
          expect(addPushNotification.firstCall.args).to.eql([notification]);

          done();
      });
    });

    it('replies with HTTP 401 on missing API secret', done => { go()
      .post(endpoint('/messages'))
      .send(Object.assign(samples.notification(), {secret: undefined}))
      .expect(401, done); });

    it('replies with HTTP 401 on invalid API secret', done => { go()
      .post(endpoint('/messages'))
      .send(samples.notification(INVALID_SECRET))
      .expect(401, done); });

    it('replies with HTTP 400 on malformed bodies', done => { go()
      .post(endpoint('/messages'))
      .send(samples.malformedNotification(API_SECRET))
      .expect(400, done); });
  });

  describe('GET /auth/:authToken/messages', function() {
    it('replies with user\'s notifications if he has some already waiting',
    done => { go()
      .get(endpoint(`/auth/${samples.users.bob.token}/messages`))
      .expect(200)
      .end(function(err, res) {
        expect(err).to.be(null);
        expect(res.body).to.be.an(Array);
        expect(res.body).to.have.length(1);

        const actual = res.body[0];
        const expected = samples.notification();

        expect(actual).to.have.property('timestamp');
        helpers.expectToEqlExceptIdSecretTimestamp(actual, expected);
        done();
    }); });

    it(`replies with user\'s notifications if user had no notifications, but got a new one within X millis`,
    function(done) {
      const username = 'alice';
      const message = {id: NEW_MESSAGE_ID, data: `notification for ${username}`};

      const add = () => { queue.addMessage(username, message, function(err, updatedMessage) {
        expect(err).to.be(null);
        expect(updatedMessage.id).to.be(message.id);
        pubsub.publish(username);
      }); }

      timeout(LP_MILLIS / 2, add);

      go()
        .get(endpoint(`/auth/${samples.users[username].token}/messages`))
        .expect(200)
        .end(function(err, res) {
          expect(err).to.be(null);
          expect(res.body).to.eql([message]);
          done();
      });
    });

    it(`replies with empty list if users had no notifications and haven\'t received new ones for X millis`,
    done => { go()
      .get(endpoint(`/auth/${samples.users.alice.token}/messages`))
      .query({after: NEW_MESSAGE_ID})
      .expect(200)
      .end(function(err, res) {
        expect(err).to.be(null);
        expect(res.body).to.eql([]);
        done();
    }); });

    it('spoofable via API_SECRET.username', done => { go()
      .get(endpoint(`/auth/${config.secret}.alice/messages`))
      .query({after: NEW_MESSAGE_ID})
      .expect(200, [], done); });

    it('replies with HTTP 401 to invalid auth token', done => { go()
      .get(endpoint("/auth/invalid-token/messages"))
      .expect(401, done); });

    it('replies HTTP 401 to invalid API_SECRET auth', done => { go()
      .get(endpoint(`/auth/invalid-${config.secret}.alice/messages`))
      .expect(401, done); });
  });
});


vasync = require 'vasync'
expect = require 'expect.js'
supertest = require 'supertest'
fakeRedis = require 'fakeredis'
fakeAuthdb = require '../fake-authdb'
notificationsApi = require "../../src/notifications-api"
PubSub = require "../../src/notifications-api/pubsub"
Queue = require "../../src/notifications-api/queue"
LongPoll = require "../../src/notifications-api/long-poll"
OnlineList = require "../../src/online-list/online-list"
server = require '../../src/server'
config = require '../../config'
samples = require './sample-data'
helpers = require './helpers'

go = supertest.bind(supertest, server)
INVALID_SECRET = 'INVALID_SECRET'
API_SECRET = process.env.API_SECRET = 'API_SECRET'
LP_MILLIS = 300 # if this is too low, we won't be able to put message in redis
                # in time for testing long poll triggering on new message
NEW_MESSAGE_ID = 2

# After tests involving getting messages are performed,
# following Online List is expected:
EXPECTED_ONLINE_LIST = ['alice', 'bob']

endpoint = (path) ->
  return "/#{config.routePrefix}#{path || ''}"

timeout = (millis, fn) -> setTimeout(fn, millis)

describe "API", () ->
  redis = fakeRedis.createClient(__filename)
  authdb = fakeAuthdb.createClient()
  queue = new Queue(redis, {maxSize: config.redis.queueSize})
  onlineList = new OnlineList(redis, {maxSize: config.onlineList.maxSize})
  longPoll = new LongPoll(LP_MILLIS)
  pubsub = new PubSub
    publisher: redis
    subscriber: fakeRedis.createClient(__filename)
    channel: config.redis.channel

  before (done) ->
    for own username, data of samples.users
      authdb.addAccount data.token, data.account

    api = notificationsApi
      authdbClient: authdb
      pubsub: pubsub
      queue: queue
      onlineList: onlineList
      longPoll: longPoll

    api(endpoint(), server)

    vasync.parallel
      funcs: [
        server.listen.bind(server, 1337)
        redis.flushdb.bind(redis)
      ], done

  after (done) ->
    vasync.parallel
      funcs: [
        pubsub.quit.bind(pubsub)
        server.close.bind(server)
      ], done

  describe 'POST /messages', () ->
    it 'creates message and replies with its ID and timestamp', (done) ->
      go()
        .post endpoint('/messages')
        .send samples.notification(API_SECRET)
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.be.an(Object)
          expect(res.body.id).to.be(1)
          expect(res.body).to.have.property('timestamp')
          done()

    it 'replies with HTTP 400 on missing API secret', (done) ->
      go()
        .post endpoint('/messages')
        .send samples.notification()
        .expect 400, done

    it 'replies with HTTP 401 on invalid API secret', (done) ->
      go()
        .post endpoint('/messages')
        .send samples.notification(INVALID_SECRET)
        .expect 401, done

    it 'replies with HTTP 400 on malformed bodies', (done) ->
      go()
        .post endpoint('/messages')
        .send samples.malformedNotification(API_SECRET)
        .expect 400, done

  describe 'GET /auth/:authToken/messages', () ->
    # Online List after this test:
    # [bob]
    it 'replies with user\'s notifications if he has some already waiting',
    (done) ->
      go()
        .get endpoint("/auth/#{samples.users.bob.token}/messages")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.be.an(Array)
          expect(res.body).to.have.length(1)

          actual = res.body[0]
          expected = samples.notification()

          expect(actual).to.have.property('timestamp')
          helpers.expectToEqlExceptIdSecretTimestamp(actual, expected)
          done()

    # Online List after this test:
    # [alice, bob]
    it 'replies with user\'s notifications if user had no notifications,
        but got a new one within X millis',
    (done) ->
      username = 'alice'
      message = {id: NEW_MESSAGE_ID, data: "notification for #{username}"}

      add = () ->
        queue.addMessage username, message, (err, messageId) ->
          expect(err).to.be(null)
          expect(messageId).to.be(message.id)
          pubsub.publish(username)

      timeout(LP_MILLIS / 2, add)

      go()
        .get endpoint("/auth/#{samples.users[username].token}/messages")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.eql([message])
          done()

    # Online List after this test:
    # [alice, bob]
    it 'replies with empty list if users had no notifications
        and haven\'t received new ones for X millis',
    (done) ->
      go()
        .get endpoint("/auth/#{samples.users.alice.token}/messages")
        .query {after: NEW_MESSAGE_ID}
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.eql([])
          done()

    it 'adds user performing request to the list of recently online users',
    (done) ->
      onlineList.get (err, list) ->
        expect(err).to.be(null)
        expect(list).to.eql(EXPECTED_ONLINE_LIST)
        done()

    it 'replies with HTTP 401 to invalid auth token', (done) ->
      go()
        .get endpoint("/auth/invalid-token/messages")
        .expect 401, done

  describe 'GET /notifications/v1/online', () ->
    it 'replies with the list of online users', (done) ->
      go()
        .get endpoint('/online')
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.eql(EXPECTED_ONLINE_LIST)
          done()

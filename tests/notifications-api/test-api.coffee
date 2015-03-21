vasync = require 'vasync'
expect = require 'expect.js'
supertest = require 'supertest'
fakeRedis = require 'fakeredis'
fakeAuthdb = require '../fake-authdb'
notificationsApi = require "../../src/notifications-api"
PubSub = require "../../src/notifications-api/pubsub"
Queue = require "../../src/notifications-api/queue"
server = require '../../src/server'
config = require '../../config'
samples = require './sample-data'
helpers = require './helpers'

go = supertest.bind(supertest, server)
INVALID_SECRET = 'INVALID_SECRET'
API_SECRET = process.env.API_SECRET = 'API_SECRET'

endpoint = (path) ->
  return "/#{config.routePrefix}#{path || ''}"

describe "API", () ->
  redis = fakeRedis.createClient(__filename)
  authdb = fakeAuthdb.createClient()
  queue = new Queue(redis, {maxSize: config.redis.queueSize})
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
    it 'creates message and replies with its ID', (done) ->
      go()
        .post endpoint('/messages')
        .send samples.notification(API_SECRET)
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.be.an(Object)
          expect(res.body.id).to.be('1')
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
    it 'returns user\'s notification right away if any exist', (done) ->
      go()
        .get endpoint("/auth/#{samples.users.bob.token}/messages")
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.be.an(Array)
          expect(res.body).to.have.length(1)
          helpers.expectToEqlExceptIdSecret(res.body[0], samples.notification())
          done()

    it 'long polling'

    it 'replies http 401 to invalid auth token', (done) ->
      go()
        .get endpoint("/auth/invalid-token/messages")
        .expect 401, done

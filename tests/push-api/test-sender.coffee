vasync = require 'vasync'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
Sender = require '../../src/push-api/sender'
Token = require '../../src/push-api/token'
TokenStorage = require '../../src/push-api/token-storage'
samples = require './samples'

describe 'Push Sender', () ->
  redis = fakeRedis.createClient(__filename)
  tokenStorage = new TokenStorage(redis)

  beforeEach (done) ->
    token = Token.fromPayload(samples.tokenData())
    notification = JSON.stringify(samples.notification())

    vasync.pipeline
      funcs: [
        (_, cb) -> redis.flushdb(cb)
        (_, cb) -> redis.lpush(Sender.PREFIX, notification, cb)
        (_, cb) -> tokenStorage.add(token, cb)
      ]
    , done

  describe '.send()', () ->
    task =
      notification: samples.notification()
      tokens: [Token.fromPayload(samples.tokenData())]

    it 'sends push notifications', (done) ->
      Sender.send task, (err, results) ->
        expect(err).to.be(null)
        expect(results.operations).to.have.length(task.tokens.length)
        expect(results.operations.every (op) -> op.status == 'ok').to.be(true)
        done()

  describe 'new Sender(redis)', () ->
    it 'creates PushSender', () ->
      sender = new Sender(redis, tokenStorage)
      expect(sender).to.be.a(Sender)

    it 'requries redis client', () ->
      create = (redisClient) -> new Sender(redisClient)
      expect(create).withArgs().to.throwError(/RedisClientRequired/)

    it 'requries TokenStorage', () ->
      create = (r, tokens) -> new Sender(r, tokens)
      expect(create).withArgs(redis).to.throwError(/TokenStorageRequired/)

  describe '#nextTask()', () ->
    sender = new Sender(redis, tokenStorage)

    it 'returns task with notification and push token
        when there are messages in the list',
    (done) ->
      sender.nextTask (err, task) ->
        expect(err).to.be(null)
        expect(task).to.be.an(Object)
        expect(task.notification).to.be.an(Object)
        expect(task.tokens).to.be.an(Array)
        expect(task.tokens).to.have.length(1)
        expect(task.tokens[0]).to.be.a(Token)
        done()

    it 'returns null when no items left in the list', (done) ->
      redis.rpop Sender.PREFIX, (err, notification) ->
        expect(err).to.be(null)

        sender.nextTask (err, task) ->
          expect(err).to.be(null)
          expect(task).to.be(null)
          done()

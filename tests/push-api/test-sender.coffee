vasync = require 'vasync'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
Sender = require '../../src/push-api/sender'
Task = require '../../src/push-api/task'
Token = require '../../src/push-api/token'
TokenStorage = require '../../src/push-api/token-storage'
samples = require './samples'
config = require '../../config'

describe 'Push Sender', () ->
  redis = fakeRedis.createClient(__filename)
  tokenStorage = new TokenStorage(redis)
  sender = new Sender(redis, tokenStorage)
  push = {some: 'push-data'}
  notification = JSON.stringify(samples.notification(push))
  notificationNobody = JSON.stringify(samples.notification(push, 'nobody'))

  beforeEach (done) ->
    token = Token.fromPayload(samples.tokenData())

    vasync.pipeline
      funcs: [
        (_, cb) -> redis.flushdb(cb)
        (_, cb) -> redis.lpush(config.pushApi.notificationsPrefix,
                               notification, notificationNobody, cb)
        (_, cb) -> tokenStorage.add(token, cb)
      ]
    , done

  describe '.send()', () ->
    token = Token.fromPayload(samples.tokenData())
    task = new Task(samples.notification(), [token])

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

    it 'returns null when no tokens found for notification reciever', (done) ->
      # remove good one, leaving notification with no receiver
      redis.multi()
        .rpop(config.pushApi.notificationsPrefix)
        .llen(config.pushApi.notificationsPrefix)
        .exec (err, replies) ->
          expect(err).to.be(null)
          expect(replies[0]).to.be(notification)
          expect(replies[1]).to.be(1)

          sender.nextTask (err, task) ->
            expect(err).to.be(null)
            expect(task).to.be(null)
            done()

    it 'returns null when no items left in the list', (done) ->
      # empty queue
      redis.del config.pushApi.notificationsPrefix, (err) ->
        expect(err).to.be(null)

        sender.nextTask (err, task) ->
          expect(err).to.be(null)
          expect(task).to.be(null)
          done()

  describe '#addNotification()', () ->
    it 'adds push notification to the head of the list', (done) ->
      notification = {some: 'thing'}

      sender.addNotification notification, (err) ->
        expect(err).to.be(null)
        redis.lrange config.pushApi.notificationsPrefix, 0, -1, (err, list) ->
          expect(err).to.be(null)
          expect(list).to.be.an(Array)
          expect(list.length).to.be.greaterThan(1)
          expect(JSON.parse(list[0])).to.eql(notification)
          done()

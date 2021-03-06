td = require 'testdouble'
fakeredis = require 'fakeredis'
expect = require 'expect.js'
vasync = require 'vasync'
Queue = require '../../src/push-api/queue'
Token = require '../../src/push-api/token'
TokenStorage = require '../../src/push-api/token-storage'
config = require '../../config'
samples = require './samples'

describe 'Queue', () ->
  redis = fakeredis.createClient(__filename)
  tokenStorage = new TokenStorage(redis)

  notification1 = samples.notification(samples.wellFormedPush())
  notification2 = samples.notification(
    samples.wellFormedPush(),
    'reciever-with-no-tokens'
  )

  resetRedis = (done) ->
    vasync.pipeline
      funcs: [
        (_, cb) -> redis.flushdb(cb)
        (_, cb) -> tokenStorage.add(Token.fromPayload(samples.tokenData()), cb)
      ]
    , done

  describe '#add()', () ->
    before(resetRedis)
    queue = new Queue(redis, tokenStorage)
    afterEach () -> td.reset()

    it 'adds push notification to the redis list', (done) ->
      queue.add notification1, (err, newLength) ->
        expect(err).to.be(null)
        expect(newLength).to.be(1)
        done()

    it 'adds push notification to the head of the list', (done) ->
      queue.add notification2, (err, newLength) ->
        expect(err).to.be(null)
        expect(newLength).to.be(2)

        redis.lrange config.pushApi.notificationsPrefix, 0, -1, (err, list) ->
          expect(err).to.be(null)
          expect(list).to.be.an(Array)

          expect(list.map (item) -> JSON.parse(item)).to.eql(
            [notification2, notification1]
          )

          done()

    it 'notifications are run through translator before adding', (done) ->
      notification = samples.notification()

      # Replace translator so we know it is called correctly.
      td.replace(queue.translator, 'process', td.function(['#process()']))
      td.when(queue.translator.process(notification, td.callback))
        .thenCallback(null, {})

      queue.add(notification, done)

  describe '#get()', () ->
    before(resetRedis)

    # reset
    # add 2 messages
    queue = new Queue(redis, tokenStorage)
    before (cb) -> queue.add(notification1, cb)
    before (cb) -> queue.add(notification2, cb)

    it 'returns task with notification and push token
        when there are messages in the list',
    (done) ->
      queue.get (err, task) ->
        expect(err).to.be(null)
        expect(task).to.be.an(Object)
        expect(task.notification).to.be.an(Object)
        expect(task.tokens).to.be.an(Array)
        expect(task.tokens).to.have.length(1)
        expect(task.tokens[0]).to.be.a(Token)
        done()

    it 'when no tokens found for notification receiver,
        returns task with 0 tokens',
    (done) ->
      queue.get (err, task) ->
        expect(err).to.be(null)
        expect(task.tokens).to.be.an(Array)
        expect(task.tokens).to.have.length(0)
        done()

    it 'returns null when no items left in the list', (done) ->
      queue.get (err, task) ->
        expect(err).to.be(null)
        expect(task).to.be(null)
        done()

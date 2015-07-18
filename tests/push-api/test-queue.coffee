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

  notification1 = samples.notification()
  notification2 = samples.notification({}, 'reciever-with-no-tokens')

  before (done) ->
    vasync.pipeline
      funcs: [
        (_, cb) -> redis.flushdb(cb)
        (_, cb) -> tokenStorage.add(Token.fromPayload(samples.tokenData()), cb)
      ]
    , done


  describe '#add()', () ->
    queue = new Queue(redis, tokenStorage)

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

  describe '#get()', () ->
    queue = new Queue(redis, tokenStorage)

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

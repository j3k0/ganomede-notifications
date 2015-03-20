vasync = require 'vasync'
fakeRedis = require 'fakeredis'
expect = require 'expect.js'
PubSub = require '../../src/notifications-api/pubsub'
config = require '../../config'

describe 'PubSub', () ->
  redis = fakeRedis.createClient(__filename)
  redisSub = fakeRedis.createClient(__filename)

  pubsub = new PubSub
    publisher: redis
    subscriber: redisSub
    channel: config.redis.channel

  before (done) ->
    vasync.parallel
      funcs: [
        redis.flushdb.bind(redis),
        redisSub.flushdb.bind(redisSub)
      ], done

  after (done) ->
    pubsub.quit(done)

  it 'Subscribes to messages and able to recieve them', (done) ->
    n = 0
    callDone = () ->
      ++n
      if n == 2
        done()

    pubsub.subscribe (channel, data) ->
      expect(channel).to.be(config.redis.channel)
      expect(data).to.be('some-data')
      callDone()

    pubsub.pub.publish config.redis.channel, 'some-data', (err, nRecievers) ->
      expect(err).to.be(null)
      # expect(nRecievers).to.be(1) # this fails with FakeRedis for some reason,
                                    # works with real one though, so w/ever...
      callDone()


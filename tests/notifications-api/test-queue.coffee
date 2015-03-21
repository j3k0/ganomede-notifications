vasync = require 'vasync'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
Queue = require '../../src/notifications-api/queue'

describe 'Queue', () ->
  redis = fakeRedis.createClient(__filename)
  queue = new Queue(redis)

  before (done) ->
    redis.flushdb(done)

  it '#nextId() returns unique String id for new message', (done) ->
    queue.nextId (err, id) ->
      expect(err).to.be(null)
      expect(id).to.be.a('string')
      done()

  describe 'Add/Get messages', () ->
    username = 'alice'
    messageData = ['msg1', 'msg2']
    messages = []

    it '#addMessage() adds message to the top of user queue and returns its id',
    (done) ->
      vasync.forEachPipeline
        func: (message, cb) -> queue.addMessage(username, {data: message}, cb)
        inputs: messageData
      , (err, results) ->
        expect(err).to.be(null)

        messageData.forEach (data, idx) ->
          id = results.operations[idx].result
          expect(id).to.be.a('string')

          messages.unshift
            id: id
            data: data

        done()

    it '#getMessages() when provided with username,
        returns list of that user\'s messages',
    (done) ->
      queue.getMessages username, (err, actual) ->
        expect(err).to.be(null)
        expect(actual).to.eql(messages)
        done()

    it '#getMessages() when provided with query object containing `username`
        and `after` returns list of that user\'s messages
        more recent than the provided id'
    (done) ->
      query = {
        username: username
        after: messages[1].id
      }

      queue.getMessages query, (err, actual) ->
        expect(err).to.be(null)
        expect(actual).to.eql(messages.slice(0, 1))
        done()

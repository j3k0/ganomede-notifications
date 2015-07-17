vasync = require 'vasync'
fakeredis = require 'fakeredis'
expect = require 'expect.js'
sinon = require 'sinon'
Sender = require '../../src/push-api/sender'
SenderCli = require '../../src/push-api/sender-cli'
Token = require '../../src/push-api/token'
Queue = require '../../src/push-api/queue'
TokenStorage = require '../../src/push-api/token-storage'
samples = require './samples'

describe 'SenderCli', () ->
  redis = fakeredis.createClient(__filename)
  storage = new TokenStorage(redis)

  queue = new Queue(redis, storage)
  sender = new Sender(samples.fakeSenders())
  sendOriginal = sender.send
  sendSpy = sinon.spy(sender.send)

  cli = new SenderCli(sender, queue)
  tickOriginal = cli.tick
  tickSpy = sinon.spy(cli.tick)

  before (done) ->
    sender.send = sendSpy
    cli.tick = tickSpy
    redis.flushdb(done)

  after () ->
    sender.send = sendOriginal
    cli.tick = tickOriginal

  describe 'new SenderCli(sender)', () ->
    it 'requires sender', () ->
      expect(-> new SenderCli).to.throwException(/SenderRequired/)

  describe '#tick()', () ->
    before (done) ->
      token = Token.fromPayload(samples.tokenData())

      vasync.parallel
        funcs: [
          storage.add.bind(storage, token)
          queue.add.bind(queue, samples.notification())
          queue.add.bind(queue, samples.notification())
          queue.add.bind(queue, samples.notification())
        ]
      , done

    it 'retrieves task, processes it and calls tick again or smth', (done) ->
      tickSpy()

      cli.on SenderCli.events.DONE, (err) ->
        expect(err).to.be(null)

        # We tick() N+1 times for N notification and once for an empty queue.
        expect(tickSpy.callCount).to.be(4)

        # We send() N times
        expect(sendSpy.callCount).to.be(3)
        for i in [0..sendSpy.callCount - 1]
          call = sendSpy.getCall(i)
          notification = call.args[0].notification
          expect(notification).to.eql(samples.notification())

        done()

expect = require 'expect.js'
Sender = require '../../src/push-api/sender'
Task = require '../../src/push-api/task'
Token = require '../../src/push-api/token'
samples = require './samples'
config = require '../../config'

describe 'Sender', () ->
  describe 'new Sender(senders)', () ->
    it 'creates Sender', () ->
      sender = new Sender({})
      expect(sender).to.be.a(Sender)

  describe '#send()', () ->
    sender = new Sender(samples.fakeSenders())
    token = Token.fromPayload(samples.tokenData())
    tokens = [token, token]
    task = new Task(samples.notification(), tokens)

    it 'sends push notifications', (done) ->
      sender.send task, (err, results) ->
        expect(err).to.be(null)

        spy = sender.senders[token.type].send
        args = spy.firstCall.args
        expectedFirstTwoArgs = [task.convert(token.type), tokens]

        expect(spy.callCount).to.be(1)
        expect(args).to.have.length(3)
        expect(args.slice(0, -1)).to.eql(expectedFirstTwoArgs)

        done()

  describe 'Sender.ApnSender', () ->
    apnSender = new Sender.ApnSender(
      cert: config.pushApi.apn.cert
      key: config.pushApi.apn.key
    )

    tokenVal = "#{Token.APN}:#{process.env.TEST_APN_TOKEN}"
    token = new Token('key_dont_matter', tokenVal)
    task = new Task(samples.notification(), [token])

    if process.env.hasOwnProperty('TEST_APN_TOKEN')
      it 'sends notifications', (done) ->
        apnSender.send task.convert(token.type), task.tokens
        apnSender.connection.once 'completed', done
    else
      it 'sends notifications (please specify TEST_APN_TOKEN env var)'

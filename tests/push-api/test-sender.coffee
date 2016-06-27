expect = require 'expect.js'
Sender = require '../../src/push-api/sender'
Task = require '../../src/push-api/task'
Token = require '../../src/push-api/token'
samples = require './samples'
config = require '../../config'

describe 'Sender.ApnSender', () ->
  apnSender = new Sender.ApnSender(
    cert: config.pushApi.apn.cert
    key: config.pushApi.apn.key
  )

  if process.env.hasOwnProperty('TEST_APN_TOKEN')
    token = new Token('key_dont_matter', {
      type: Token.APN,
      value: process.env.TEST_APN_TOKEN
    })

    task = new Task(samples.notification(), [token])

    it 'sends notifications', (done) ->
      this.timeout(5000)
      apnSender.send task.convert(token.type), task.tokens
      apnSender.connection.once 'transmissionError', (code, note, device) ->
        done(new Error("APN Error code=#{code}"))

      apnSender.connection.once 'completed', () ->
        # Give a chance for error to get back to us
        setTimeout(done, 4500)
  else
    it 'sends notifications (please specify TEST_APN_TOKEN env var)'

describe 'Sender.GcmSender', () ->
  hasTestInfo = process.env.hasOwnProperty('TEST_GCM_API_KEY') &&
    process.env.hasOwnProperty('TEST_GCM_TOKEN')
  unless hasTestInfo
    return it "sends notifications (please specify env vars:
      TEST_GCM_API_KEY and TEST_GCM_TOKEN)"

  it 'sends notifications', (done) ->
    gcmSender = new Sender.GcmSender(process.env.TEST_GCM_API_KEY)
    token = Token.fromPayload(
      samples.tokenData('gcm', process.env.TEST_GCM_TOKEN)
    )
    notif = samples.notification
      title: [ "your_turn_title", "DollyWood" ]
      message: [ "your_turn_message", "DollyWood" ]
    task = new Task(notif, [token])

    gcmSender.once Sender.events.SUCCESS, (noteId, gcmToken) ->
      expect(noteId).to.be(samples.notification().id)
      expect(gcmToken).to.be(token.data())
      done()

    gcmSender.once Sender.events.FAILURE, (err, noteId, token) ->
      done(err)

    gcmSender.send task.convert(token.type), task.tokens

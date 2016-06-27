apn = require 'apn'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
config = require '../../config'
Task = require '../../src/push-api/task'
Token = require '../../src/push-api/token'
TokenStorage = require '../../src/push-api/token-storage'
samples = require './samples'
tokenData = samples.tokenData

describe 'Token', () ->
  data = tokenData()
  token = Token.fromPayload(data)

  it 'new Token() works', () ->
    create = (key, type, value) -> new Token(key, {type, value})
    expect(create).withArgs('key', 'type', 'value').to.not.throwException()
    expect(create('k', 't', 'v')).to.be.a(Token)

  it 'key is `config.pushApi.tokensPrefix:username:app`', () ->
    expected = [config.pushApi.tokensPrefix, data.username, data.app].join(':')
    expect(token.key).to.be(expected)
    expect(token.key).to.match(/data-v2/)

  it 'type is one of Token.TYPES', () ->
    expect(token.type).to.be(Token.APN)
    expect(token.type in Token.TYPES).to.be(true)

  it 'device is defaultDevice', () ->
    expect(token.device).to.be('defaultDevice')

  it 'allows specify device', () ->
    d = {key: 'k', type: 'apn', device: 'd', value: 'v'}
    expect(new Token(d.key, d)).to.eql(d)

  it 'value is `token`', () ->
    expect(token.value).to.be(data.value)

  describe '#data()', () ->
    it 'returns token value without type', () ->
      expect(token.data()).to.be(data.value)

    it 'correctly processes token values with colons', () ->
      payload = {
        username: 'alice'
        app: 'some/app'
        type: 'gcm'
        value: 'value:with:colons'
      }

      expect(Token.fromPayload(payload).data()).to.be(payload.value)

describe 'TokenStorage', () ->
  redis = fakeRedis.createClient(__filename)
  data = tokenData()
  storage = new TokenStorage(redis)
  token = Token.fromPayload(data)

  describe '#add()', () ->
    before (done) -> redis.flushdb(done)

    it 'adds token to store', (done) ->
      storage.add token, (err, added) ->
        expect(err).to.be(null)
        expect(added).to.be(true)

        redis.hgetall token.key, (err, obj) ->
          expect(err).to.be(null)
          expect(obj).to.eql({'apn:defaultDevice': token.value})
          done()

    it 'does not store duplicate tokens', (done) ->
      storage.add token, (err, added) ->
        expect(err).to.be(null)
        expect(added).to.be(false)
        done()

    it 'updates old tokens of same type', (done) ->
      updatedData = tokenData('apn', 'new-apn-token')
      updatedToken = Token.fromPayload(updatedData)

      storage.add updatedToken, (err, added) ->
        expect(err).to.be(null)
        expect(added).to.be(false)
        redis.hgetall token.key, (err, obj) ->
          expect(err).to.be(null)
          expect(obj).to.eql({'apn:defaultDevice': 'new-apn-token'})
          done()

  describe '#get()', () ->
    before (done) -> redis.flushdb(done)
    before (done) -> storage.add(token, done)

    it 'retrieves user\'s tokens for certain game', (done) ->
      storage.get data.username, data.app, (err, tokens) ->
        expect(err).to.be(null)
        expect(tokens).to.be.an(Array)
        expect(tokens).to.have.length(1)
        expect(tokens.every (t) -> t instanceof Token).to.be(true)
        expect(tokens[0]).to.eql(token)
        done()

    it 'returns [] in case redis hash is missing for user', (done) ->
      storage.get 'i-have-no-tokens', data.app, (err, tokens) ->
        expect(err).to.be(null)
        expect(tokens).to.be.eql([])
        done()

describe 'Task', () ->
  token = Token.fromPayload(tokenData())
  push =
    app: samples.notification().from
    title: ['title-loc-key'],
    message: ['message-loc-key', 'message-loc-arg-1', 'message-loc-arg-2']
  notification = samples.notification(push)
  task = new Task(notification, [token])

  describe 'new Task(notification, tokens)', () ->
    create = (n, t) -> new Task(n, t)

    it 'requires notification', () ->
      expect(create).withArgs().to.throwException(/NotificationRequired/)

    it 'requires tokens', () ->
      expect(create).withArgs({}).to.throwException(/TokensRequired/)

  describe '#convert()', () ->
    it 'converts notification according to token.type', () ->
      expected = Task.converters[Token.APN](notification)
      expect(expected).to.eql(task.convert(token.type))

    it 'doesnt convert same token type twice returning from cache instead',
    () ->
      # Checks that we got exact reference to object inside inner task cache
      # and not new object created by one of the Task.converters
      expect(task.convert(token.type)).to.be(task.converted[token.type])

    it 'throws if convertion to token.type is not supported', () ->
      uknownType = 'HAHA'
      error = new RegExp("#{uknownType} convertion not supported")
      convert = task.convert.bind(task)
      expect(convert).withArgs(uknownType).to.throwException(error)

  describe 'Task.converters', () ->
    describe 'Token.APN', () ->
      it 'converts to apn.Notification', () ->
        apnNote = Task.converters[Token.APN](notification)
        expect(apnNote).to.be.a(apn.Notification)

      describe '.alert(push)', () ->
        alert = Task.converters[Token.APN].alert

        it 'returns localization object when .push has 2 arrays', () ->
          expect(alert(push)).to.eql({
            'title-loc-key': 'title-loc-key'
            'title-loc-args': []
            'loc-key': 'message-loc-key'
            'loc-args': ['message-loc-arg-1', 'message-loc-arg-2']
          })

        it 'returns default string from config in other cases', () ->
          expect(alert({})).to.be(config.pushApi.apn.defaultAlert)

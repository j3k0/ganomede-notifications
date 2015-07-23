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
    create = (k, v) -> new Token(k, v)
    expect(create).withArgs('key', 'value').to.not.throwException()
    expect(create('k', 'v')).to.be.a(Token)

  it 'keyed at `config.pushApi.tokensPrefix:username:app`', () ->
    expected = [config.pushApi.tokensPrefix, data.username, data.app].join(':')
    expect(token.key).to.be(expected)

  it 'value is `type:token`', () ->
    expected = [data.type, data.value].join(':')
    expect(token.value).to.be(expected)

  it 'type is one of Token.TYPES', () ->
    expect(token.type).to.be(Token.APN)
    expect(token.type in Token.TYPES).to.be(true)

  it '#data() returns token value without type', () ->
    expect(token.data()).to.be(data.value)

describe 'TokenStorage', () ->
  redis = fakeRedis.createClient(__filename)
  data = tokenData()
  storage = new TokenStorage(redis)
  token = Token.fromPayload(data)

  before (done) ->
    redis.flushdb(done)

  it 'adds token to store', (done) ->
    storage.add token, (err, added) ->
      expect(err).to.be(null)
      expect(added).to.be(true)

      redis.smembers token.key, (err, members) ->
        expect(err).to.be(null)
        expect(members).to.be.an(Array)
        expect(members).to.have.length(1)
        expect(members[0]).to.eql(token.value)
        done()

  it 'does not store duplicate tokens', (done) ->
    storage.add token, (err, added) ->
      expect(err).to.be(null)
      expect(added).to.be(false)
      done()

  it 'retrieves user\'s tokens for certain game', (done) ->
    storage.get data.username, data.app, (err, tokens) ->
      expect(err).to.be(null)
      expect(tokens).to.be.an(Array)
      expect(tokens).to.have.length(1)
      expect(tokens.every (t) -> t instanceof Token).to.be(true)
      expect(tokens[0]).to.eql(token)
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

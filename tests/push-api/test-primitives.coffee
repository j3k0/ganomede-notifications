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
    type: 'someone_loves_someone',
    title: ['Love {1}', 'bob'],
    message: ['Did you know? {1} loves {2}', 'alice', 'bob']
  notification = samples.notification(push)
  task = new Task(notification, [token])

  describe 'new Task(notification, tokens)', () ->
    create = (n, t) -> new Task(n, t)

    it 'requires notification', () ->
      expect(create).withArgs().to.throwException(/NotificationRequired/)

    it 'requires tokens', () ->
      expect(create).withArgs({}).to.throwException(/TokensRequired/)

  describe '#convertPayload()', () ->
    it 'converts push payload according to token.type', () ->
      expected = Task.converters[Token.APN](push)
      expect(expected).to.eql(task.convertPayload(token.type))

    it 'returns notification when conversion isn\'t required', () ->
      t = new Task(samples.notification(), [])
      expect(t.convertPayload(Token.APN)).to.eql(samples.notification())

    it 'doesnt convert same token type twice returning from cache instead',
    () ->
      # Checks that we got exact reference to object inside inner task cache
      # and not new object created by one of the Task.converters
      expect(task.convertPayload(token.type)).to.be(task.converted[token.type])

    it 'throws if convertion to token.type is not supported', () ->
      uknownType = 'HAHA'
      error = new RegExp("#{uknownType} convertion not supported")
      convert = task.convertPayload.bind(task)
      expect(convert).withArgs(uknownType).to.throwException(error)

  describe 'Task.converters', () ->
    it 'Token.APN', () ->
      expect(Task.converters[Token.APN](push)).to.eql(
        'title': 'Love {1}'
        'title-key': 'someone_loves_someone_title'
        'title-args': ['bob']
        'body': 'Did you know? {1} loves {2}'
        'loc-key': 'someone_loves_someone_message'
        'loc-args': ['alice', 'bob']
      )

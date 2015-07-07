expect = require 'expect.js'
fakeRedis = require 'fakeredis'
config = require '../../config'
Token = require '../../src/push-api/token'
TokenStorage = require '../../src/push-api/token-storage'
samples = require './samples'
tokenData = samples.tokenData

describe 'Token', () ->
  data = tokenData()
  token = Token.fromPayload(data)

  it 'keyed at `Token.PREFIX:username:app`', () ->
    expected = [Token.PREFIX, data.username, data.app].join(':')
    expect(token.key).to.be(expected)

  it 'value is `type:token`', () ->
    expected = [data.type, data.value].join(':')
    expect(token.value).to.be(expected)

  it 'type is one of Token.TYPES', () ->
    expect(token.type).to.be(Token.IOS)
    expect(token.type in Token.TYPES).to.be(true)

  describe '.removeServiceVersion()', () ->
    test = (name, unversionedName) ->
      actual = Token.removeServiceVersion(name)
      expected = if arguments.length == 1 then name else unversionedName
      expect(actual).to.be(expected)

    it 'returns name without a version from versioned service name', () ->
      test('service/v1', 'service')
      test('service/something/v1', 'service/something')

    it 'returns original string if no version is present', () ->
      test('service')
      test('service/v')
      test('service/v-2')
      test('service/vABC')
      test('service/not-a-version/more?')

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

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

  it 'keyed at `config.pushApi.tokensPrefix:username:app`', () ->
    expected = [config.pushApi.tokensPrefix, data.username, data.app].join(':')
    expect(token.key).to.be(expected)

  it 'value is `type:token`', () ->
    expected = [data.type, data.value].join(':')
    expect(token.value).to.be(expected)

  it 'type is one of Token.TYPES', () ->
    expect(token.type).to.be(Token.APN)
    expect(token.type in Token.TYPES).to.be(true)

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

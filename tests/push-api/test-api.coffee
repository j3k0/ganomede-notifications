vasync = require 'vasync'
ganomedeHelpers = require 'ganomede-helpers'
supertest = require 'supertest'
fakeRedis = require 'fakeredis'
expect = require 'expect.js'
fakeAuthDb = require '../fake-authdb'
pushApi = require '../../src/push-api'
Token = require '../../src/push-api/token'
TokenStorage = require '../../src/push-api/token-storage'
config = require '../../config'
samples = require './samples'

describe 'Push API', () ->
  server = ganomedeHelpers.restify.createServer()
  go = supertest.bind(supertest, server)
  authdb = fakeAuthDb.createClient()
  redis = fakeRedis.createClient(__filename)
  tokenStorage = new TokenStorage(redis)
  api = pushApi
    authdb: authdb
    tokenStorage: tokenStorage

  endpoint = (path) ->
    return "/#{config.routePrefix}#{path || ''}"

  before (done) ->
    authdb.addAccount('alice-auth-token', {username: 'alice'})
    api(config.routePrefix, server)

    vasync.parallel
      funcs: [
        redis.flushdb.bind(redis)
        server.listen.bind(server, 1337)
      ]
    , done

  after (done) ->
    server.close(done)

  describe 'POST /<auth>/push-token', () ->
    it 'adds user\'s push token storage', (done) ->
      data = samples.tokenData()
      token = Token.fromPayload(data)

      go()
        .post endpoint('/auth/alice-auth-token/push-token')
        .send data
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)

          tokenStorage.get data.username, data.app, (err, tokens) ->
            expect(err).to.be(null)
            expect(tokens).to.be.an(Array)
            expect(tokens).to.have.length(1)
            expect(tokens[0]).to.be.a(Token)
            expect(tokens[0]).to.eql(token)
            done()

    it 'body must include username, app, type, value', (done) ->
      data = samples.tokenData()
      data.value = ''

      go()
        .post endpoint('/auth/alice-auth-token/push-token')
        .send data
        .expect 400, done

    it 'spoofable via API_SECRET', (done) ->
      go()
        .post endpoint("/auth/#{config.secret}.alice/push-token")
        .send samples.tokenData()
        .expect 200, done

    it 'requires auth', (done) ->
      go()
        .post endpoint('/auth/invalid-auth-token/push-token')
        .send samples.tokenData()
        .expect 401, done

    it 'requires valid API_SECRET', (done) ->
      go()
        .post endpoint("/auth/invalid-#{config.secert}.someone/push-token")
        .send samples.tokenData()
        .expect 401, done


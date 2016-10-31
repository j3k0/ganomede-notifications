expect = require 'expect.js'
supertest = require 'supertest'
sinon = require 'sinon'
fakeAuthdb = require '../fake-authdb'
onlineApi = require '../../src/online-api'
server = require '../../src/server'
config = require '../../config'

go = supertest.bind(supertest, server)

endpoint = (path) ->
  return "/#{config.routePrefix}#{path || ''}"

describe 'Online API', () ->
  authdb = fakeAuthdb.createClient()
  someJson = ['alice']
  managerSpy = {
    add: sinon.spy((listId, profile, cb) -> setImmediate(cb, null, someJson)),
    get: sinon.spy((listId, cb) -> setImmediate(cb, null, someJson))
  }

  aliceProfile = {
    username: 'alice',
    email: 'alice@example.com'
  }

  before (done) ->
    authdb.addAccount('token-alice', aliceProfile)

    api = onlineApi({
      onlineList: managerSpy,
      authdbClient: authdb
    })

    api(config.routePrefix, server)
    server.listen(1337, done)

  after (cb) ->
    server.close(cb)

  describe 'GET /online', () ->
    it 'fetches default list', (done) ->
      go()
        .get(endpoint('/online'))
        .expect(200, someJson)
        .end (err, res) ->
          expect(err).to.be(null)
          expect(managerSpy.get.lastCall.args[0]).to.be(undefined)
          done()

    it 'fetches specific lists', (done) ->
      go()
        .get endpoint('/online/specific-list')
        .expect(200, someJson)
        .end (err, res) ->
          expect(err).to.be(null)
          expect(managerSpy.get.lastCall.args[0]).to.eql('specific-list')
          done()

  describe 'POST /auth/:authToken/online', () ->
    it 'adds to default list', (done) ->
      go()
        .post(endpoint('/auth/token-alice/online'))
        .expect(200, someJson)
        .end (err, res) ->
          expect(err).to.be(null)
          expect(managerSpy.add.lastCall.args.slice(0, -1)).to.eql([
            undefined,
            aliceProfile
          ])
          done()

    it 'adds to specific list', (done) ->
      go()
        .post(endpoint('/auth/token-alice/online/specific-list'))
        .expect(200, someJson)
        .end (err, res) ->
          expect(err).to.be(null)
          expect(managerSpy.add.lastCall.args.slice(0, -1)).to.eql([
            'specific-list',
            aliceProfile
          ])
          done()

    it 'allows username spoofing via API_SECRET', (done) ->
      go()
        .post(endpoint("/auth/#{config.secret}.whoever/online"))
        .expect(200, someJson, done)

    it 'requires valid auth token', (done) ->
      go()
        .post endpoint('/auth/invalid-token/online')
        .expect(401, done)

    it 'replies HTTP 401 to invalid API_SECRET auth', (done) ->
      go()
        .post(endpoint("/auth/invalid-#{config.secret}.alice/online"))
        .expect(401, done)

# vim: ts=2:sw=2:et:

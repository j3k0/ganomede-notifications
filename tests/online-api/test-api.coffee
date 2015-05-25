vasync = require 'vasync'
expect = require 'expect.js'
supertest = require 'supertest'
fakeRedis = require 'fakeRedis'
onlineApi = require '../../src/online-api'
OnlineList = require '../../src/online-api/online-list'
server = require '../../src/server'
config = require '../../config'
common = require './common'

go = supertest.bind(supertest, server)

endpoint = (path) ->
  return "/#{config.routePrefix}#{path || ''}"

describe 'Online API', () ->
  redis = fakeRedis.createClient(__filename)
  onlineList = new OnlineList(redis, {maxSize: 5})

  before (cb) ->
    api = onlineApi(onlineList: onlineList)

    # This allows us to add user to an onlie list.
    server.get endpoint('/i-am-online/:username'),
    # First we fake AuthDB middleware (no auth logic)
    (req, res, next) ->
      req.params.user = {username: req.params.username}
      next()
    ,
    # Then we use `api` provided middleware that registers user and
    # would normaly be placed before some common endpoint users hit.
    api.updateOnlineListMiddleware
    ,
    # Respond something, so we know everyting went well.
    (req, res, next) ->
      res.json({ok: true})
      next()

    # This sets up /online endpoint that returns list of recently
    # online users.
    api(config.routePrefix, server)

    server.listen(1337, cb)

  after (cb) ->
    server.close(cb)

  describe 'updateOnlineListMiddleware()', () ->
    hitEndpoint = (username, cb) ->
      go()
        .get(endpoint("/i-am-online/#{username}"))
        .expect(200, {ok: true}, cb)

    # Add users to list 1 by 1.
    before (done) ->
      usernames = common.TEST_LIST
      vasync.forEachPipeline
        inputs: usernames
        func: (username, cb) ->
          # Delay by 1ms for predictable order.
          setTimeout(hitEndpoint.bind(null, username, cb), 1)
      , done

    it 'hitting middleware adds user to the list', (done) ->
      onlineList.get (err, list) ->
        expect(err).to.be(null)
        expect(list).to.eql(common.reverseArray(common.TEST_LIST))
        done()

  describe 'GET /online', () ->
    it 'returns json list of usernames of recently online users', (done) ->
      go()
        .get endpoint('/online')
        .expect 200
        .end (err, res) ->
          expect(err).to.be(null)
          expect(res.body).to.eql(common.reverseArray(common.TEST_LIST))
          done()

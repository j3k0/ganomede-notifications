vasync = require 'vasync'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
OnlineList = require '../../src/notifications-api/online-list'

TEST_LIST = ['alice', 'bob', 'jdoe']
TEST_MAX_SIZE = TEST_LIST.length

clone = (obj) -> JSON.parse(JSON.stringify(obj))

reverseArray = (arr) ->
  copy = clone(arr)
  reversed = []

  for item in copy
    reversed.unshift(item)

  return reversed

describe 'OnlineList', () ->
  redisClient = fakeRedis.createClient(__filename)
  list = new OnlineList(redisClient, {maxSize: TEST_MAX_SIZE})

  before (cb) ->
    redisClient.flushdb(cb)

  # Adding users 1 by 1 in order defined in TEST_LIST
  # (resulting online list is reversed).
  initList = (callback) ->
    vasync.forEachPipeline
      func: list.add.bind(list)
      inputs: TEST_LIST
      , callback

  getList = (callback) ->
    list.get(callback)

  it 'adds users to the top of the list', (done) ->
    initList (err) ->
      expect(err).to.be(null)

      # Since most recent users go to the top of the list,
      # we expect to get reversed copy of TEST_LIST.
      getList (err, list) ->
        expect(err).to.be(null)
        expect(list).to.eql(reverseArray(TEST_LIST))
        done()

  it 'trims list at options.maxSize usernames', (done) ->
    username = 'alice-will-get-trimmed'
    expected = reverseArray(TEST_LIST)          # initial (from #add() test)
    expected.unshift(username)                  # add new username
    expected = expected.slice(0, TEST_MAX_SIZE) # trim to max size

    list.add username, (err) ->
      expect(err).to.be(null)

      getList (err, list) ->
        expect(err).to.be(null)
        expect(list).to.eql(expected)
        done()

  it 'retrives list', (done) ->
    getList (err, wrappedList) ->
      expect(err).to.be(null)

      redisClient.lrange list.key, 0, -1, (err, rawList) ->
        expect(err).to.be(null)
        expect(wrappedList).to.have.length(TEST_MAX_SIZE)
        expect(wrappedList).to.eql(rawList)
        done()

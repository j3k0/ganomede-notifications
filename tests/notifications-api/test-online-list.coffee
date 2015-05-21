vasync = require 'vasync'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
OnlineList = require '../../src/notifications-api/online-list'

TEST_LIST = ['alice', 'bob', 'jdoe']
TEST_MAX_SIZE = TEST_LIST.length

delay = (ms, fn) -> setTimeout(fn, ms)

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
      # have to setTimeout so SET is sorted in predictable order.
      func: (username, cb) -> delay(1, list.add.bind(list, username, cb))
      inputs: TEST_LIST
    , callback

  getList = (callback) ->
    list.get(callback)

  getRawList = (callback) ->
    redisClient.zrange list.key, 0, -1, callback

  describe '#add()', () ->
    it 'adds users to the list sorted by -timestamp of request
        (newer request first)',
    (done) ->
      initList (err, results) ->
        expect(err).to.be(null)

        getRawList (err, list) ->
          expect(err).to.be(null)
          expect(list).to.eql(reverseArray(TEST_LIST))
          done()

    it 'does not store duplicate usernames, but rather updates their score',
    (done) ->
      username = TEST_LIST[0]

      list.add username, (err) ->
        expect(err).to.be(null)

        getRawList (err, list) ->
          expect(err).to.be(null)

          # We expect <username> to be moved to the top of the list.
          expected = reverseArray(TEST_LIST)
          expected.pop()              # remove from the end
          expected.unshift(username)  # add to the top

          expect(list).to.eql(expected)
          done()

    it 'trims list at options.maxSize usernames, removing oldest requests',
    (done) ->
      username = "#{TEST_LIST[0]}-will-get-trimmed"
      expected = reverseArray(TEST_LIST)          # initial (from #add() test)
      expected.unshift(username)                  # add new username
      expected = expected.slice(0, TEST_MAX_SIZE) # trim to max size

      initList (err) ->
        expect(err).to.be(null)

        list.add username, (err) ->
          expect(err).to.be(null)

          getList (err, list) ->
            expect(err).to.be(null)
            expect(list).to.eql(expected)
            done()

  describe '#get()', () ->
    before (cb) ->
      initList(cb)

    it 'retrives list', (done) ->
      getList (err, wrappedList) ->
        expect(err).to.be(null)
        expect(wrappedList).to.eql(reverseArray(TEST_LIST))

        getRawList (err, rawList) ->
          expect(err).to.be(null)
          expect(wrappedList).to.eql(rawList)
          done()

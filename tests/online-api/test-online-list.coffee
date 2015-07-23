vasync = require 'vasync'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
OnlineList = require '../../src/online-api/online-list'
common = require './common'

TEST_LIST = common.TEST_LIST
TEST_MAX_SIZE = TEST_LIST.length

delay = common.delay
clone = common.clone
reverseArray = common.reverseArray

describe 'OnlineList', () ->
  redisClient = fakeRedis.createClient(__filename)
  list = new OnlineList(redisClient, {maxSize: TEST_MAX_SIZE})

  before (cb) ->
    redisClient.flushdb(cb)

  # Adding users 1 by 1 in order defined in TEST_LIST
  # (resulting online list is reversed).
  initList = (callback) ->
    timeout = 2
    TEST_LIST.forEach (username) ->
      setTimeout ->
        list.add username
      , timeout
      timeout += 10
    setTimeout callback, timeout

  getList = (callback) ->
    list.get(callback)

  getRawList = (callback) ->
    redisClient.zrange list.key, 0, -1, callback

  describe '#add()', () ->
    it 'adds users to the list sorted by -timestamp of request
        (newer request first)',
    (done) ->
      initList (err, results) ->
        expect(!err).to.be.ok()

        getRawList (err, list) ->
          expect(!err).to.be.ok()
          expect(list).to.eql(reverseArray(TEST_LIST))
          done()
          #console.log list, TEST_LIST

    it 'does not store duplicate usernames, but rather updates their score',
    (done) ->
      username = TEST_LIST[0]

      list.add username
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
        expect(!err).to.be.ok()

        list.add username
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

# vim: ts=2:sw=2:et:

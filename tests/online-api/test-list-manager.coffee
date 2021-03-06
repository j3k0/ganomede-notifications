async = require 'async'
expect = require 'expect.js'
fakeRedis = require 'fakeredis'
ListManager = require '../../src/online-api/list-manager'

describe 'ListManager', () ->
  redisClient = fakeRedis.createClient(__filename)
  alice = {username: 'alice'}
  bob = {username: 'bob'}
  jdoe = {username: 'jdoe'}
  invisible = {_secret: true}

  before (cb) -> redisClient.flushdb(cb)

  describe '#userVisible()', () ->
    createList = (re) -> new ListManager(redisClient, {
      maxSize: 3,
      invisibleUsernameRegExp: re
    })

    it 'authorized users are visible', () ->
      user = {username: 'jdoe'}
      expect(createList().userVisible(user)).to.be(true)

    it 'users without username are NOT visible', () ->
      user = {}
      expect(createList().userVisible(user)).to.be(false)

    it 'users with username matching invisible regexp are NOT visible', () ->
      user = {username: 'testjdoe'}
      re = /^test/
      expect(createList(re).userVisible(user)).to.be(false)

    it 'users with username not matching regexp are visible', () ->
      user = {username: 'jdoetest'}
      re = /^test/
      expect(createList(re).userVisible(user)).to.be(true)

    it '_secret users are NOT visible', () ->
      user = {username: 'fake', _secret: true}
      expect(createList().userVisible(user)).to.be(false)

  describe '#add()', () ->
    manager = new ListManager(redisClient, {
      maxSize: 2,
      prefix: 'test-add'
    })

    it 'adds username to the default list and returns updated list', (done) ->
      manager.add undefined, alice, (err, newList) ->
        expect(err).to.be(null)
        expect(newList).to.eql([alice.username])
        done()

    it 'usernames are sorted by TIME ADDED desc', (done) ->
      manager.add undefined, bob, (err, newList) ->
        expect(err).to.be(null)
        expect(newList).to.eql([bob.username, alice.username])
        done()

    it 'adding same username twice means score update', (done) ->
      manager.add undefined, alice, (err, newList) ->
        expect(err).to.be(null)
        expect(newList).to.eql([alice.username, bob.username])
        done()

    it 'list is treamed at options.maxSize usernames', (done) ->
      manager.add undefined, jdoe, (err, newList) ->
        expect(err).to.be(null)
        expect(newList).to.eql([jdoe.username, alice.username])
        done()

    it 'if listId is truthy, it is used instead of default', (done) ->
      manager.add 'new-list', bob, (err, newList) ->
        expect(err).to.be(null)
        expect(newList).to.eql([bob.username])
        done()

    it 'invisible users are not added', (done) ->
      manager.add 'invisible-list', invisible, (err, newList) ->
        expect(err).to.be(null)
        expect(newList).to.eql([])
        done()

  describe '#get()', () ->
    manager = new ListManager(redisClient, {
      prefix: 'test-get'
      maxSize: 3
    })

    initList = (listId) -> (done) -> async.eachSeries(
      [alice, bob, jdoe],
      (profile, cb) -> manager.add(listId, profile, cb),
      done
    )

    before(initList())
    before(initList('not-default'))

    it 'retrives default list', (done) ->
      manager.get undefined, (err, list) ->
        expect(err).to.be(null)
        expect(list.length).to.equal(3)
        expect(list.indexOf(jdoe.username)).to.be.greaterThan(-1)
        expect(list.indexOf(bob.username)).to.be.greaterThan(-1)
        expect(list.indexOf(alice.username)).to.be.greaterThan(-1)
        done()

    it 'retrives not-default list', (done) ->
      manager.get 'not-default', (err, list) ->
        expect(err).to.be(null)
        expect(list.length).to.equal(3)
        expect(list.indexOf(jdoe.username)).to.be.greaterThan(-1)
        expect(list.indexOf(bob.username)).to.be.greaterThan(-1)
        expect(list.indexOf(alice.username)).to.be.greaterThan(-1)
        done()

    it 'treats missing lists as empty', (done) ->
      manager.get 'missing', (err, list) ->
        expect(err).to.be(null)
        expect(list).to.eql([])
        done()

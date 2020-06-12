import * as async from 'async';
import expect from 'expect.js';
import * as fakeRedis from 'fakeredis';
import ListManager from '../../src/online-api/list-manager';
import {before, describe, it} from 'mocha';

describe('ListManager', function() {
  const redisClient = fakeRedis.createClient();
  const alice = {username: 'alice'};
  const bob = {username: 'bob'};
  const jdoe = {username: 'jdoe'};
  const invisible = {_secret: true};

  before(cb => { redisClient.flushdb(cb); });

  describe('#userVisible()', function() {
    const createList = (re?) => new ListManager(redisClient, {
      maxSize: 3,
      invisibleUsernameRegExp: re
    });

    it('authorized users are visible', function() {
      const user = {username: 'jdoe'};
      expect(createList().userVisible(user)).to.be(true);
    });

    it('users without username are NOT visible', function() {
      const user = {};
      expect(createList().userVisible(user)).to.be(false);
    });

    it('users with username matching invisible regexp are NOT visible', function() {
      const user = {username: 'testjdoe'};
      const re = /^test/;
      expect(createList(re).userVisible(user)).to.be(false);
    });

    it('users with username not matching regexp are visible', function() {
      const user = {username: 'jdoetest'};
      const re = /^test/;
      expect(createList(re).userVisible(user)).to.be(true);
    });

    it('_secret users are NOT visible', function() {
      const user = {username: 'fake', _secret: true};
      expect(createList().userVisible(user)).to.be(false);
    });
  });

  describe('#add()', function() {
    const manager = new ListManager(redisClient, {
      maxSize: 2,
      prefix: 'test-add'
    });

    it('adds username to the default list and returns updated list', done => { manager.add(undefined, alice, function(err, newList) {
      expect(err).to.be(null);
      expect(newList).to.eql([alice.username]);
      done();
    }); });

    it('usernames are sorted by TIME ADDED desc', done => { manager.add(undefined, bob, function(err, newList) {
      expect(err).to.be(null);
      expect(newList).to.eql([bob.username, alice.username]);
      done();
    }); });

    it('adding same username twice means score update', done => { manager.add(undefined, alice, function(err, newList) {
      expect(err).to.be(null);
      expect(newList).to.eql([alice.username, bob.username]);
      done();
    }); });

    it('list is treamed at options.maxSize usernames', done => { manager.add(undefined, jdoe, function(err, newList) {
      expect(err).to.be(null);
      expect(newList).to.eql([jdoe.username, alice.username]);
      done();
    }); });

    it('if listId is truthy, it is used instead of default', done => { manager.add('new-list', bob, function(err, newList) {
      expect(err).to.be(null);
      expect(newList).to.eql([bob.username]);
      done();
    }); });

    it('invisible users are not added', done => { manager.add('invisible-list', invisible, function(err, newList) {
      expect(err).to.be(null);
      expect(newList).to.eql([]);
      done();
    }); });
  });

  describe('#get()', function() {
    const manager = new ListManager(redisClient, {
      prefix: 'test-get',
      maxSize: 3
    });

    const initList = (listId?) => done => { async.eachSeries(
      [alice, bob, jdoe],
      (profile, cb) => manager.add(listId, profile, cb),
      done
    ); }

    before(initList());
    before(initList('not-default'));

    it('retrives default list', done => { manager.get(undefined, function(err, list) {
      expect(err).to.be(null);
      expect(list.length).to.equal(3);
      expect(list.indexOf(jdoe.username)).to.be.greaterThan(-1);
      expect(list.indexOf(bob.username)).to.be.greaterThan(-1);
      expect(list.indexOf(alice.username)).to.be.greaterThan(-1);
      done();
    }); });

    it('retrives not-default list', done => { manager.get('not-default', function(err, list) {
      expect(err).to.be(null);
      expect(list.length).to.equal(3);
      expect(list.indexOf(jdoe.username)).to.be.greaterThan(-1);
      expect(list.indexOf(bob.username)).to.be.greaterThan(-1);
      expect(list.indexOf(alice.username)).to.be.greaterThan(-1);
      done();
    }); });

    it('treats missing lists as empty', done => { manager.get('missing', function(err, list) {
      expect(err).to.be(null);
      expect(list).to.eql([]);
      done();
    }); });
  });
});

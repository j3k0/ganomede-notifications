import expect from 'expect.js';
import supertest from 'supertest';
import * as sinon from 'sinon';
import * as restify from 'restify';
import fakeAuthdb from '../fake-authdb';
import onlineApi from '../../src/online-api';
import serverMod from '../../src/server';
import config from '../../config';
import {after, before, describe, it} from 'mocha';

describe('Online API', function() {
  let go:any = null;
  let server:restify.Server|null = null;
  const endpoint = path => `/${config.routePrefix}${path || ''}`;

  const authdb = fakeAuthdb.createClient();
  const someJson = ['alice'];
  const managerSpy = {
    add: sinon.spy((listId, profile, cb) => setImmediate(cb, null, someJson)),
    get: sinon.spy((listId, cb) => setImmediate(cb, null, someJson))
  };

  const aliceProfile = {
    username: 'alice',
    email: 'alice@example.com'
  };

  before(function(done) {
    server = serverMod.createServer();
    go = () => supertest(server);

    authdb.addAccount('token-alice', aliceProfile);

    const api = onlineApi({
      onlineList: managerSpy,
      authdbClient: authdb
    });

    api(config.routePrefix, server);
    server.listen(1337, done);
  });

  after(cb => { server!.close(cb); });

  describe('GET /online', function() {
    it('fetches default list', done => { go()
      .get(endpoint('/online'))
      .expect(200, someJson)
      .end(function(err, res) {
        expect(err).to.be(null);
        expect(managerSpy.get.lastCall.args[0]).to.be(undefined);
        done();
    }); });

    it('fetches specific lists', done => { go()
      .get(endpoint('/online/specific-list'))
      .expect(200, someJson)
      .end(function(err, res) {
        expect(err).to.be(null);
        expect(managerSpy.get.lastCall.args[0]).to.eql('specific-list');
        done();
    }); });
  });

  describe('POST /auth/:authToken/online', function() {
    it('adds to default list', done => { go()
      .post(endpoint('/auth/token-alice/online'))
      .expect(200, someJson)
      .end(function(err, res) {
        expect(err).to.be(null);
        expect(managerSpy.add.lastCall.args.slice(0, -1)).to.eql([
          undefined,
          aliceProfile
        ]);
        done();
    }); });

    it('adds to specific list', done => { go()
      .post(endpoint('/auth/token-alice/online/specific-list'))
      .expect(200, someJson)
      .end(function(err, res) {
        expect(err).to.be(null);
        expect(managerSpy.add.lastCall.args.slice(0, -1)).to.eql([
          'specific-list',
          aliceProfile
        ]);
        done();
    }); });

    it('allows username spoofing via API_SECRET', done => { go()
      .post(endpoint(`/auth/${config.secret}.whoever/online`))
      .expect(200, someJson, done); });

    it('requires valid auth token', done => { go()
      .post(endpoint('/auth/invalid-token/online'))
      .expect(401, done); });

    it('replies HTTP 401 to invalid API_SECRET auth', done => { go()
      .post(endpoint(`/auth/invalid-${config.secret}.alice/online`))
      .expect(401, done); });
  });
});

// vim: ts=2:sw=2:et:

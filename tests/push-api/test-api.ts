import * as vasync from 'vasync';
import supertest from 'supertest';
import * as fakeRedis from 'fakeredis';
import expect from 'expect.js';
import fakeAuthDb from '../fake-authdb';
import pushApi from '../../src/push-api';
import Token from '../../src/push-api/token';
import TokenStorage from '../../src/push-api/token-storage';
import config from '../../config';
import samples from './samples';
import * as restify from 'restify';
import {after, before, describe, it} from 'mocha';

function createServer() {
  const server = restify.createServer();
  server.use(restify.plugins.queryParser());
  server.use(restify.plugins.bodyParser());
  server.use(restify.plugins.gzipResponse());
  return server;
};

describe('Push API', function() {
  const server = createServer();
  const go = () => supertest(server);
  const authdb = fakeAuthDb.createClient();
  const redis = fakeRedis.createClient('push-api/test-api');
  const tokenStorage = new TokenStorage(redis);
  const api = pushApi({
    authdb,
    tokenStorage
  });

  const endpoint = path => `/${config.routePrefix}${path || ''}`;

  before(function(done) {
    authdb.addAccount('alice-auth-token', {username: 'alice'});
    api(config.routePrefix, server);

    vasync.parallel({
      funcs: [
        redis.flushdb.bind(redis),
        server.listen.bind(server, 1337)
      ]
    }
    , done);
  });

  after(done => { server.close(done); });

  describe('POST /<auth>/push-token', function() {
    it('adds user\'s push token storage', function(done) {
      const data = samples.tokenData();
      const token = Token.fromPayload(data);

      go()
        .post(endpoint('/auth/alice-auth-token/push-token'))
        .send(data)
        .expect(200)
        .end(function(err, res) {
          expect(err).to.be(null);

          tokenStorage.get(data.username, data.app, function(err, tokens) {
            expect(err).to.be(null);
            expect(tokens).to.be.an(Array);
            expect(tokens).to.have.length(1);
            expect(tokens![0]).to.be.a(Token);
            expect(tokens![0]).to.eql(token);
            done();
          });
      });
    });

    it('body must include username, app, type, value', function(done) {
      const data = samples.tokenData();
      data.value = '';

      go()
        .post(endpoint('/auth/alice-auth-token/push-token'))
        .send(data)
        .expect(400, done);
    });

    it('spoofable via API_SECRET', done => { go()
      .post(endpoint(`/auth/${config.secret}.alice/push-token`))
      .send(samples.tokenData())
      .expect(200, done); });

    it('requires auth', done => { go()
      .post(endpoint('/auth/invalid-auth-token/push-token'))
      .send(samples.tokenData())
      .expect(401, done); });

    it('requires valid API_SECRET', done => { go()
      .post(endpoint(`/auth/invalid-${config.secret}.someone/push-token`))
      .send(samples.tokenData())
      .expect(401, done); });
  });
});


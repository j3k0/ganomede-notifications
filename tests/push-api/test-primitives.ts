/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import apn from 'apn';
import expect from 'expect.js';
import fakeRedis from 'fakeredis';
import config from '../../config';
import Task, { apnAlert } from '../../src/push-api/task';
import {Token, TokenDef, TokenData} from '../../src/push-api/token';
import TokenStorage from '../../src/push-api/token-storage';
import samples from './samples';
import {before, describe, it} from 'mocha';

const { tokenData } = samples;

describe('Token', function() {
  const data = tokenData();
  const token = Token.fromPayload(data);

  it('new Token() works', function() {
    const create = (key, type, value) => new Token(key, {type, value});
    expect(create).withArgs('key', 'type', 'value').to.not.throwException();
    expect(create('k', 't', 'v')).to.be.a(Token);
  });

  it('key is `config.pushApi.tokensPrefix:username:app`', function() {
    const expected = [config.pushApi.tokensPrefix, data.username, data.app].join(':');
    expect(token.key).to.be(expected);
    expect(token.key).to.match(/data-v2/);
  });

  it('type is one of Token.TYPES', function() {
    expect(token.type).to.be(Token.APN);
    expect(Array.from(Token.TYPES).includes(token.type)).to.be(true);
  });

  it('device is defaultDevice', () => expect(token.device).to.be('defaultDevice'));

  it('allows specify device', function() {
    const d:TokenData = {type: 'apn', device: 'd', value: 'v'};
    expect(new Token('k', d)).to.eql({key: 'k', type: 'apn', device: 'd', value: 'v'});
  });

  it('value is `token`', () => expect(token.value).to.be(data.value));

  describe('#data()', function() {
    it('returns token value without type', () => expect(token.data()).to.be(data.value));

    it('correctly processes token values with colons', function() {
      const payload: TokenDef = {
        username: 'alice',
        app: 'some/app',
        type: 'gcm',
        value: 'value:with:colons'
      };

      expect(Token.fromPayload(payload).data()).to.be(payload.value);
    });
  });
});

describe('TokenStorage', function() {
  const redis = fakeRedis.createClient();
  const data = tokenData();
  const storage = new TokenStorage(redis);
  const token = Token.fromPayload(data);

  describe('#add()', function() {
    before(done => redis.flushdb(done));

    it('adds token to store', done => { storage.add(token, function(err, added) {
      expect(err).to.be(null);
      expect(added).to.be(true);

      redis.hgetall(token.key, function(err, obj) {
        expect(err).to.be(null);
        expect(obj).to.eql({'apn:defaultDevice': token.value});
        done();
      });
    }); });

    it('does not store duplicate tokens', done => { storage.add(token, function(err, added) {
      expect(err).to.be(null);
      expect(added).to.be(false);
      done();
    }); });

    it('updates old tokens of same type', function(done) {
      const updatedData = tokenData('apn', 'new-apn-token');
      const updatedToken = Token.fromPayload(updatedData);

      storage.add(updatedToken, function(err, added) {
        expect(err).to.be(null);
        expect(added).to.be(false);
        redis.hgetall(token.key, function(err, obj) {
          expect(err).to.be(null);
          expect(obj).to.eql({'apn:defaultDevice': 'new-apn-token'});
          done();
        });
      });
    });
  });

  describe('#get()', function() {
    before(done => { redis.flushdb(done); });
    before(done => { storage.add(token, done); });

    it('retrieves user\'s tokens for certain game', done => { storage.get(data.username, data.app, function(err, tokens) {
      expect(err).to.be(null);
      expect(tokens).to.be.an(Array);
      expect(tokens).to.have.length(1);
      expect(tokens!.every(t => t instanceof Token)).to.be(true);
      expect(tokens![0]).to.eql(token);
      done();
    }); });

    it('returns [] in case redis hash is missing for user', done => { storage.get('i-have-no-tokens', data.app, function(err, tokens) {
      expect(err).to.be(null);
      expect(tokens).to.be.eql([]);
      done();
    }); });
  });
});

describe('Task', function() {
  const token = Token.fromPayload(tokenData());
  const push = {
    app: samples.notification().from,
    title: ['title-loc-key'],
    message: ['message-loc-key', 'message-loc-arg-1', 'message-loc-arg-2']
  };
  const notification = samples.notification(push);
  const task = new Task(notification, [token]);

  describe('new Task(notification, tokens)', function() {
    const create = (n, t) => new Task(n, t);

    it('requires notification', () => { expect(create).withArgs().to.throwException(/NotificationRequired/); });

    it('requires tokens', () => { expect(create).withArgs({}).to.throwException(/TokensRequired/); });
  });

  describe('#convert()', function() {
    it('converts notification according to token.type', function() {
      const expected = Task.converters.apn(notification);
      expect(expected).to.eql(task.convert(token.type as 'apn'));
    });

    it('doesnt convert same token type twice returning from cache instead',
    () => {
      // Checks that we got exact reference to object inside inner task cache
      // and not new object created by one of the Task.converters
      expect(task.convert(token.type as 'apn')).to.be(task.converted[token.type]);
    });

    it('throws if convertion to token.type is not supported', function() {
      const uknownType = 'HAHA';
      const error = new RegExp(`${uknownType} convertion not supported`);
      const convert = task.convert.bind(task);
      expect(convert).withArgs(uknownType).to.throwException(error);
    });
  });

  describe('Task.converters', () => {
    describe('Token.APN', function() {
      it('converts to apn.Notification', function() {
        const apnNote = Task.converters[Token.APN](notification);
        expect(apnNote).to.be.a(apn.Notification);
      });

      describe('.alert(push)', function() {
        const alert = apnAlert;

        it('returns localization object when .push has 2 arrays', () => {
          expect(alert(push)).to.eql({
            'title-loc-key': 'title-loc-key',
            'title-loc-args': [],
            'loc-key': 'message-loc-key',
            'loc-args': ['message-loc-arg-1', 'message-loc-arg-2']
          });
        });

        it('returns default string from config in other cases', () => {
          expect(alert({})).to.be(config.pushApi.apn.defaultAlert);
        });
      });
    });
  });
});

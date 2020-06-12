/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import * as vasync from 'vasync';
import expect from 'expect.js';
import * as fakeRedis from 'fakeredis';
import Queue from '../../src/notifications-api/queue';
import {before, describe, it} from 'mocha';

const MAX_SIZE = 3;

describe('Queue', function() {
  const redis = fakeRedis.createClient();
  const queue = new Queue(redis, {maxSize: MAX_SIZE});

  before(done => { redis.flushdb(done); });

  it('#nextId() returns unique String id for new message', done => { queue.nextId(function(err, id) {
    expect(err).to.be(null);
    expect(id).to.be.a('number');
    done();
  }); });

  describe('Add/Get messages', function() {
    const username = 'alice';
    const messageData = ['msg1', 'msg2', 'msg3', 'msg4', 'msg5'];
    let messages:Array<{id:number, data:any}> = [];

    it(`#addMessage() adds message to the top of user queue and returns message with filled in id field`,
    done => { vasync.forEachPipeline({
      func(message, cb) { return queue.addMessage(username, {data: message}, cb); },
      inputs: messageData
    }
    , function(err, results) {
      expect(err).to.be(null);

      messageData.forEach(function(data, idx) {
        const {
          id
        } = results.operations[idx].result;
        expect(id).to.be.a('number');

        messages.unshift({
          id,
          data
        });
      });

      messages = messages.slice(0, MAX_SIZE);
      done();
    }); });

    it('#addMessage() trims queue to queue#maxSize', done => { queue.getMessages(username, function(err, actual) {
      expect(err).to.be(null);
      expect(actual).to.be.an(Array);
      expect(actual).to.have.length(MAX_SIZE);
      done();
    }); });

    it(`#getMessages() when provided with username, returns list of that user\'s messages`,
    done => { queue.getMessages(username, function(err, actual) {
      expect(err).to.be(null);
      expect(actual).to.eql(messages);
      done();
    }); });

    it(`#getMessages() when provided with query object containing \`username\` and \`after\` returns list of that user\'s messages more recent than the provided id`,
    function(done) {
      const query = {
        username,
        after: messages[1].id
      };

      queue.getMessages(query, function(err, actual) {
        expect(err).to.be(null);
        expect(actual).to.eql(messages.slice(0, 1));
        done();
      });
    });
  });
});

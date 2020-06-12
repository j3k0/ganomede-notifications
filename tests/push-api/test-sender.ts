import expect from 'expect.js';
import Sender from '../../src/push-api/sender';
import Task from '../../src/push-api/task';
import Token from '../../src/push-api/token';
import samples from './samples';
import config from '../../config';
import {describe, it} from 'mocha';

describe('Sender.ApnSender', function() {
  const apnSender = new Sender.ApnSender({
    cert: config.pushApi.apn.cert,
    key: config.pushApi.apn.key
  });

  if (process.env.hasOwnProperty('TEST_APN_TOKEN')) {
    const token = new Token('key_dont_matter', {
      type: 'apn',
      device: 'apple',
      value: process.env.TEST_APN_TOKEN!
    });

    const task = new Task(samples.notification(), [token]);

    it('sends notifications', function(done) {
      apnSender.send(task.convert(token.type), task.tokens);
      apnSender.connection.once('transmissionError', (code, note, device) => done(new Error(`APN Error code=${code}`)));

      apnSender.connection.once('completed', () => // Give a chance for error to get back to us
        setTimeout(done, 4500));
    }).timeout(5000);
  } else {
    it('sends notifications (please specify TEST_APN_TOKEN env var)');
  }
});

describe('Sender.GcmSender', function() {
  const hasTestInfo = process.env.hasOwnProperty('TEST_GCM_API_KEY') &&
    process.env.hasOwnProperty('TEST_GCM_TOKEN');
  if (!hasTestInfo) {
    it(`sends notifications (please specify env vars: TEST_GCM_API_KEY and TEST_GCM_TOKEN)`);
  }
  else {
    it('sends notifications', function(done) {
      const gcmSender = new Sender.GcmSender(process.env.TEST_GCM_API_KEY);
      const token = Token.fromPayload(
        samples.tokenData('gcm', process.env.TEST_GCM_TOKEN)
      );
      const notif = samples.notification({
        title: [ "your_turn_title", "DollyWood" ],
        message: [ "your_turn_message", "DollyWood" ]});
      const task = new Task(notif, [token]);

      gcmSender.once(Sender.events.SUCCESS, function(noteId, gcmToken) {
        expect(noteId).to.be(samples.notification().id);
        expect(gcmToken).to.be(token.data());
        done();
      });

      function toError(e) {
        if (e && !(e instanceof Error))
          return new Error(JSON.stringify(e));
        return e;
      }

      gcmSender.once(Sender.events.FAILURE, (err, noteId, token) => done(toError(err)));

      gcmSender.send(task.convert(token.type), task.tokens);
    });
  }
});

import * as apn from 'apn';
import * as gcm from 'node-gcm';
import * as events from 'events';
import Token from './token';
import config from '../../config';
import logMod from '../log';
import {Logger} from '../log';
const log:Logger = logMod.child({sender:true});

// TODO
// listen for errors:
// https://github.com/argon/node-apn/blob/master/doc/connection.markdown
class ApnSender {
  connection: apn.Connection;
  log: Logger;

  constructor(options) {
    options.production = options.production || !config.debug;
    this.connection = new apn.Connection(options);
    this.log = log.child({apn:true});
  }

  send(notification, tokens) {
    this.log.info({
      id: notification.payload.id,
      to: notification.payload.to
    }, "sending APN");
    const devices = tokens.map(token => new apn.Device(token.data()));
    return this.connection.pushNotification(notification, devices);
  }

  close(cb) {
    this.connection.once('disconnected', cb);
    return this.connection.shutdown();
  }
}

class GcmSender extends events.EventEmitter {
  gcm:gcm.Sender;
  log:Logger;
  constructor(apiKey) {
    super();
    this.gcm = new gcm.Sender(apiKey);
    this.log = log.child({gcm: true});
  }

  _send(message, ids) {
    return this.gcm.sendNoRetry(message,
      {registrationTokens: ids},
      (err, result) => {
        // Unlike APN sender, we need to manually emit N times for each token.
        const notifId = message.params.data.notificationId;
        return Array.from(ids).map((token) =>
          err ?
            this.emit(Sender.events.FAILURE, {httpCode: err}, notifId, token)
          :
            this.emit(Sender.events.SUCCESS, notifId, token));
    });
  }

  send(gcmMessage, tokens) {
    this.log.info({
      id: gcmMessage.params.data.notificationId,
      to: gcmMessage.params.data.notificationTo
    }, "sending GCM");
    const registrationIds = tokens.map(token => token.data());
    return this._send(gcmMessage, registrationIds);
  }
}

export interface Senders {
  apn: ApnSender;
  gcm: GcmSender;
}

export class Sender extends events.EventEmitter {
  static events = {
    // notification processed somehow
    // cb(senderType, notificationId, token)
    PROCESSED: 'processed',
    // notification succeeded
    // cb(senderType, notificationId, token)
    SUCCESS: 'sent',
    // notification failed
    // cb(senderType, error, notificationId, token)
    FAILURE: 'failed'
  };

  static GcmSender = GcmSender;
  static ApnSender = ApnSender;

  senders: Senders;

  constructor(senders: Senders) {
    super();
    this.senders = senders || {};

    // APN events
    // (no way to know about success)
    this.senders[Token.APN].connection.on('transmitted', (notification, device) => {
      return this.emit(Sender.events.PROCESSED, Token.APN, notification.payload.id, device);
    });

    this.senders[Token.APN].connection.on('transmissionError', (code, n, device) => {
      return this.emit(Sender.events.FAILURE, Token.APN, {code}, n.payload.id, device);
    });

    // GCM Events
    // (since it is POST, we can reliably know if notification was accpeted)
    this.senders[Token.GCM].on(Sender.events.SUCCESS, (notifId, token) => {
      this.emit(Sender.events.PROCESSED, Token.GCM, notifId, token);
      return this.emit(Sender.events.SUCCESS, Token.GCM, notifId, token);
    });

    this.senders[Token.GCM].on(Sender.events.FAILURE, (error, notifId, token) => {
      this.emit(Sender.events.PROCESSED, Token.GCM, notifId, token);
      return this.emit(Sender.events.FAILURE, Token.GCM, error, notifId, token);
    });
  }

  // Sends push notification from task.notification for each one of task.tokens.
  send(task) {
    // Group tokens by type
    const groupedTokens = {};
    task.tokens.forEach(function(token) {
      groupedTokens[token.type] = groupedTokens[token.type] || [];
      return groupedTokens[token.type].push(token);
    });

    // For each token group, invoke appropriate sender
    const sendFunctions:Array<() => void> = [];
    for (let type of Object.keys(groupedTokens || {})) {
      const tokens = groupedTokens[type];
      const sender = this.senders[type];
      if (!sender) {
        throw new Error(`No sender specified for ${type} token type`);
      }

      const fn = () =>
        sender.send(task.convert(type), tokens);
      sendFunctions.push(fn);
    }

    // Exec those functions
    return sendFunctions.forEach(fn => fn());
  }
}

export default Sender;

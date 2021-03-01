import * as apn from 'apn';
import * as gcm from 'node-gcm';
import * as events from 'events';
import Token, { TokenType } from './token';
import config from '../../config';
import logMod from '../log';
import {Logger} from '../log';
import Task from './task';
const log:Logger = logMod.child({sender:true});

export class ApnSenderOptions {
  production?:boolean;
  cert?: string;
  key?: string;
  buffersNotifications?: boolean;
  maxConnections?: number;
}

// TODO
// listen for errors:
// https://github.com/argon/node-apn/blob/master/doc/connection.markdown
export class ApnSender {
  connection: apn.Provider;
  log: Logger;

  constructor(options:ApnSenderOptions) {
    options.production = options.production || !config.debug;
    this.connection = new apn.Provider(options);
    this.log = log.child({apn:true});
  }

  send(notification:apn.Notification, tokens:string[]) {
    this.log.info({
      id: notification.payload.id,
      to: notification.payload.to
    }, "sending APN");
    return this.connection.send(notification, tokens);
  }

  close(cb) {
    this.connection.once('disconnected', cb);
    return this.connection.shutdown();
  }
}

export class GcmSender extends events.EventEmitter {
  gcm:gcm.Sender;
  log:Logger;
  constructor(apiKey:string) {
    super();
    this.gcm = new gcm.Sender(apiKey);
    this.log = log.child({gcm: true});
  }

  _send(message:gcm.Message, ids:string[]) {
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

  send(gcmMessage:gcm.Message, tokens:string[]) {
    this.log.info({
      id: gcmMessage.params.data.notificationId,
      to: gcmMessage.params.data.notificationTo
    }, "sending GCM");
    // const registrationIds = tokens.map(token => token.data());
    return this._send(gcmMessage, tokens);// registrationIds);
  }
}

export interface Senders {
  apn: ApnSender;
  gcm: GcmSender;
}

export interface ApnSenderConverter {
  converter: () => apn.Notification;
  sender: ApnSender;
}
export interface GcmSenderConverter {
  converter: () => gcm.Message;
  sender: GcmSender;
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
  send(task:Task) {
    // Group tokens by type
    const groupedTokens: {
      apn?: Token[];
      gcm?: Token[];
    } = {};
    task.tokens.forEach(function(token) {
      groupedTokens[token.type] = groupedTokens[token.type] || [];
      return groupedTokens[token.type]!.push(token);
    });

    // For each token group, invoke appropriate sender
    const sendFunctions:Array<() => void> = [];
    for (let type of (Object.keys(groupedTokens || {}) as TokenType[])) {
      const tokens:undefined|Token[] = groupedTokens[type];
      if (!tokens) continue;
      if (!this.senders[type])
        throw new Error(`No sender specified for ${type} token type`);
      const actor:ApnSenderConverter|GcmSenderConverter = {
        sender: this.senders[type],
        converter: () => task.convert(type as any)
      } as any;
      const fn = () => {
        actor.sender.send(actor.converter(), tokens.map(t => t.data()));
      }
      sendFunctions.push(fn);
    }

    // Exec those functions
    return sendFunctions.forEach(fn => fn());
  }
}

export default Sender;

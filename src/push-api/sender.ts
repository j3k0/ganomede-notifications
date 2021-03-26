import * as apn from '@parse/node-apn';
import * as gcm from 'node-gcm';
import * as events from 'events';
import Token, { TokenType } from './token';
// import config from '../../config';
import logModI from '../log';
import {Logger} from '../log';
import Task from './task';
const logMod:Logger = logModI.child({sender:true});

export class ApnSenderOptions {
  production?:boolean;
  cert?: string;
  key?: string;
  // buffersNotifications?: boolean;
  // maxConnections?: number;
}

export class ApnSender extends events.EventEmitter {
  connection: apn.Provider;
  log: Logger;

  constructor(options:ApnSenderOptions) {
    super();
    // options.production = true; // options.production || !config.debug;
    const providerOptions = {
      ...options,
      production: true,
    };
    this.connection = new apn.Provider(providerOptions);
    this.log = logModI.child({ apn: true });
    this.log.info({ providerOptions }, 'apn.initialized');
  }

  send(notification:apn.Notification, tokens:string[]) {
    this.log.debug({
      tokens,
      id: notification.payload.id,
      to: notification.payload.to,
      aps: notification.aps,
    }, "apn.send");
    if (!notification.aps.alert) {
      this.log.warn({
        to: notification.payload.to,
        notification: {
          ...notification,
          payload: null
        }
      }, "apn.notification contains no alert!");
      this.emit(Sender.events.FAILURE, notification, {
        failed: [{
          device: tokens[0],
          error: 'notification contains no alert message',
        }],
      });
      return;
    }
    this.connection.send(notification, tokens).then(responses => {
      this.log.debug({ responses }, "apn.responded");
      if (responses.sent?.length > 0)
        this.emit(Sender.events.SUCCESS, notification, responses);
      else
        this.emit(Sender.events.FAILURE, notification, responses);
    });
  }

  close(cb) {
    this.log.info('apn.close');
    this.connection.once('disconnected', cb);
    this.connection.shutdown();
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
    this.senders[Token.APN].on(Sender.events.SUCCESS, (notification, responses:apn.Responses) => {
      const sent = responses.sent?.[0];
      const notifId = notification?.payload?.id;
      const token = sent?.device;
      const to = notification?.payload?.to || '';
      logMod.info({
        to: notification?.payload?.to,
        timestamp: notification?.payload?.timestamp
      }, `#${notifId} apn success > ${to}`);
      this.emit(Sender.events.PROCESSED, Token.APN, notifId, token);
      this.emit(Sender.events.SUCCESS, Token.APN, notifId, token);
    });

    this.senders[Token.APN].on(Sender.events.FAILURE, (notification, responses:apn.Responses) => {
      const failed = responses.failed?.[0];
      const notifId = notification?.payload?.id;
      const token = failed?.device;
      const from = notification?.payload?.from || '';
      const to = notification?.payload?.to || '';
      const message = responses?.failed?.[0]?.error?.message
        || responses?.failed?.[0]?.response?.reason
        || 'unknown error';
      logMod.warn({ device: token, id: notifId, to, from, responses },
        `#${notifId} apn failure > ${to}: ${message}`);
      this.emit(Sender.events.PROCESSED, Token.APN, notifId, token);
      this.emit(Sender.events.FAILURE, Token.APN, failed, notifId, token);
      // TODO: Remove invalid tokens from the database.
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

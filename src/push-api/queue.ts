// Redis queue that stores push notifications to be sent.

import Task from './task';
import config from '../../config';
import logMod from '../log';
import Translator from './translator';
import UserLocale from './user-locale';
import { RedisClient } from 'redis';
import TokenStorage from './token-storage';
import { Notification } from '../types';

const translator = new Translator();

class Queue {
  redis: RedisClient;
  tokenStorage: TokenStorage;

  constructor(redis, tokenStorage) {
    this.redis = redis;
    this.tokenStorage = tokenStorage;
    if (!this.redis) {
      throw new Error('RedisClientRequired');
    }

    if (!this.tokenStorage) {
      throw new Error('TokenStorageRequired');
    }
  }

  // Add notification to the queue.
  // callback(err)
  add(notification: Notification, callback?: (err: Error|null, newLength: number|null) => void): void {
    const log = logMod.child({ to: notification?.to, timestamp: notification?.timestamp });
    const json = JSON.stringify(notification);
    this.redis.lpush(config.pushApi.notificationsPrefix, json, function(err: Error|null, newLength: number|null): void {
      if (err) {
        log.error({
          err,
          notification,
          queue: config.pushApi.notificationsPrefix
        }, 'Failed to add notification to the queue');
      }

      if (callback)
        callback(err, newLength);
    });
  }

  // Look into redis list for new push notifications to be send.
  // If there are notification, retrieve push tokens for them.
  // callback(err, task)
  _rpop(callback: (err:Error|null, notification?:Notification) => void): void {
    logMod.debug('_rpop');
    this.redis.rpop(config.pushApi.notificationsPrefix, function(err, notificationJson) {
      if (err) {
        logMod.error({err}, 'Failed to .rpop push notification');
        callback(err);
      }

      callback(null, JSON.parse(notificationJson));
    });
  }


  // Example notification data:
  //    notification: {
  //   "from": "chat/v1",
  //   "to": "kago042",
  //   "type": "message",
  //   "data": {
  //     "roomId": "triominos/v1/kago042/nipe755",
  //     "from": "nipe755",
  //     "timestamp": "1587367081025",
  //     "type": "triominos/v1",
  //     "message": "yo"
  //   },
  //   "push": {
  //     "titleArgsTypes": [
  //       "directory:name"
  //     ],
  //     "messageArgsTypes": [
  //       "string",
  //       "directory:name"
  //     ],
  //     "message": [
  //       "new_message_message",
  //       "yo",
  //       "nipe755"
  //     ],
  //     "app": "triominos/v1",
  //     "title": [
  //       "new_message_title",
  //       "nipe755"
  //     ]
  //   },
  //   "timestamp": 1587367081519,
  //   "id": 1132529133
  // }
  _task(notification: Notification, callback: (err: Error|null, task:Task|null) => void): void {
    const log = logMod.child({ to: notification?.to, timestamp: notification?.timestamp });
    log.debug('_task');
    const now = +new Date();
    const ten_minutes_ago = now - (600 * 1000);
    const tooOld = n => n.timestamp && (n.timestamp < ten_minutes_ago);
    if (!notification) {
      return callback(null, null);
    }
    if (tooOld(notification)) {
      log.info({
        id: notification.id,
        timestamp: (new Date(notification.timestamp)).toISOString()
      }, `#${notification.id} [skip] notification is too old`);
      return callback(null, new Task(notification, []));
    }

    // if (notification.to === 'kago042') {
    log.debug({
      from: notification.from,
      to: notification.to,
      type: notification.type,
      push: notification.push
    }, 'sending...');
    // }

    this.tokenStorage.get(notification.to, notification.push?.app || '', function(err, tokens) {
      // token data:
      // tokens: [{
      // "key": "notifications:push-tokens:data-v2:kago042:triominos/v1",
      //   "type": "gcm",
      //   "device": "defaultDevice",
      //   "value": "qjeklwqjeklwqje---some-garbage"
      // }]
      if (err) {
        log.error({
          err,
          notification
        }, 'Failed to get tokens for notification');
        return callback(err, null);
      }

      if (notification.secret) {
        delete notification.secret;
      }

      // if (notification.to === 'kago042') {
      log.debug({ tokens }, 'tokens');
      // }

      if (tokens!.length > 0) {
        translate(notification, function(translated: Message) {
          if (translated.title && translated.message) {
            notification.translated = translated;
            log.debug({ translated }, 'notification translated');
            callback(null, new Task(notification, tokens));
          } else {
            log.info(`#${notification.id} [skip] no translation`);
            callback(null, new Task(notification, []));
          }
        });
      } else {
        log.info(`#${notification.id} [skip] no tokens`);
        callback(null, new Task(notification, []));
      }
    });
  }

  get(callback: (err:Error|null, task:Task|null) => void): void {
    this._rpop((err, notification) => {
      if (err) return callback(err, null);
      this._task(notification!, callback);
    });
  }
}

export interface Message {
  title: string;
  message: string;
}
export type TranslateCallback = (msg: Message) => void;

var translate = (notification: Notification, callback: TranslateCallback) => UserLocale.fetch(notification.to, function(locale) {

  const log = logMod.child({ to: notification?.to, timestamp: notification?.timestamp });
  log.debug({ locale, username: notification.to }, 'locale fetched');
  translator.translate(
    locale,
    notification.push?.title || [],
    notification.push?.titleArgsTypes || [],
    title => translator.translate(
      locale,
      notification.push?.message || [],
      notification.push?.messageArgsTypes || [],
      message => callback({
        title,
        message})));
});

export default Queue;

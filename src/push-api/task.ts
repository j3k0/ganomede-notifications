import * as apn from 'apn';
import * as gcm from 'node-gcm';
import Token from './token';
import config from '../../config';
import log from '../log';
import {Notification, NotificationPush} from '../types';
import { Message } from './queue';

class Task {

  notification:Notification;
  tokens:any;
  converted:any;

  constructor(notification:Notification, tokens) {
    this.notification = notification;
    this.tokens = tokens;
    if (!this.notification) {
      throw new Error('NotificationRequired');
    }

    if (!this.tokens) {
      throw new Error('TokensRequired');
    }

    // Store result of converting @notification to provider format
    this.converted = {};
  }

  convert(type) {
    if (!this.converted.hasOwnProperty(type)) {
      if (!Task.converters.hasOwnProperty(type)) {
        throw new Error(`${type} convertion not supported`);
      }

      this.converted[type] = Task.converters[type](this.notification);
    }

    return this.converted[type];
  }

  static converters = {
    apn: function(notification:Notification):apn.Notification {
      const note = new apn.Notification();
      note.expiry = Math.floor(Date.now() / 1000) + config.pushApi.apn.expiry;
      note.badge = config.pushApi.apn.badge;
      note.sound = config.pushApi.apn.sound;
      note.payload = {
        id: notification.id,
        type: notification.type,
        from: notification.from,
        to: notification.to,
        timestamp: notification.timestamp,
        data: notification.data,
        push: notification.push
      };
      note.alert = apnAlert(notification.push);
      return note;
    },

    gcm: function(notification:Notification) {
      return new gcm.Message({
        data: {
          notificationId: notification.id, // for easier debug prints
          notificationTo: notification.to, // for easier debug prints
          json: JSON.stringify(notification)
        },
          // title_loc_key: androidKeyFormat(headString push.title)
          // title_loc_args: headString push.title.slice(1)
          // body_loc_key: androidKeyFormat(headString push.message)
          // body_loc_args: headString push.message.slice(1)
        notification: gcmNotification(
          notification.push, notification.translated)
      });
    }
  };
}

export function apnAlert(push) {
  const localized = Array.isArray(push.title) && Array.isArray(push.message);
  if (localized) {
    return {
      'title-loc-key': push.title[0],
      'title-loc-args': push.title.slice(1),
      'loc-key': push.message[0],
      'loc-args': push.message.slice(1)
    };
  } else {
    // Not sure what notification.alert should be while converting to APN.
    log.warn('Not sure what apnNotification.alert should be given push', push);
    return config.pushApi.apn.defaultAlert;
  }
};

export function gcmNotification(push?:NotificationPush, translated?:Message) {
  return {
    // tag: push.app
    icon: config.pushApi.gcm.icon,

    title: translated?.title || push?.title[0],

    // title_loc_key: androidKeyFormat(push.title[0])
    // title_loc_args: push.title.slice(1)
    // body_loc_key: androidKeyFormat(push.message[0])
    // body_loc_args: push.message.slice(1)
    // priority: 'high'
    // contentAvailable: true
    body: translated?.message || push?.message[0],
  }
};

// const headString = function(a) { if (a != null ? a.length : undefined) { return a[0]; } else { return ''; } };

// const androidKeyFormat = s => s.replace(/\{1\}/g, "%1").replace(/\{2\}/g, "%2");

export default Task;

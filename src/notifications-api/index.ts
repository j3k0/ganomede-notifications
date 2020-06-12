import log from "../log";
import * as authdb from "authdb";
import * as redis from "redis";
import * as restify from "restify";
import * as restifyErrors from "restify-errors";
import authdbHelper from '../authdb-helper';
import config from '../../config';
import PubSub from './pubsub';
import Queue, { QueueQuery } from './queue';
import LongPoll from './long-poll';
import { AuthDBClient } from "authdb";
import { Notification } from "../types";

const {
  hasOwnProperty
} = Object.prototype;

const sendError = function(err:Error, next:restify.Next, type?:string) {
  if (!type) { type = 'error'; }
  log[type](err);
  next(err);
};
/*
const sendShortError = function(err, next, type) {
  if (type == null) { type = 'error'; }
  log[type](err.message);
  return next(err);
};
*/

export interface NotificationsApiOptions {
  authdbClient?: AuthDBClient;
  addPushNotification?: (message:Notification) => void;
  pubsub?: PubSub;
  queue?: Queue;
  longPoll?: LongPoll;
}

const notificationsApi = function(options?: NotificationsApiOptions) {
  //
  // Init
  //

  // configure authdb client
  if (options == null) { options = {}; }
  const authdbClient = options.authdbClient || authdb.createClient({
    host: config.authdb.host,
    port: config.authdb.port});

  // Some notifications may require sending push notification.
  // This function is called with `message` to be sent in it.
  // It is meant to store message into redis queue that holds push notifications
  // to be sent out.
  let addPushNotification = options.addPushNotification || function(_msg:Notification) {};
  if (!options.addPushNotification) {
    log.warn(`No options.addPushNotification() function provided to notificationsApi(). It will be noop()`);
  }

  // notificatinos redis pub/sub
  // notifications redis queue

  const client = (!options.queue || !options.pubsub)
    ? redis.createClient(config.redis.port, config.redis.host)
    : null;

  const pubsub: PubSub = options.pubsub ||
    new PubSub({
      publisher: client!,
      subscriber: redis.createClient(config.redis.port, config.redis.host),
      channel: config.redis.channel
    });

  const queue: Queue = options.queue || new Queue(client!, {maxSize: config.redis.queueSize});

  // notify the listeners of incoming messages
  // called when new data is available for a user
  pubsub.subscribe((_channel:string, username:string) => // if there's a listener, trigger it
    longPoll.trigger(username));

  var longPoll = options.longPoll || new LongPoll(config.longPollDurationMillis);

  // configure the testuser authentication token (to help with manual testing)
  if (process.env.TESTUSER_AUTH_TOKEN) {
    authdbClient.addAccount(process.env.TESTUSER_AUTH_TOKEN,
      {username: "testuser"}, function() {});
  }

  //
  // Middlewares
  //

  // Populates req.params.user with value returned from authDb.getAccount()
  const authMiddleware = authdbHelper.create({
    authdbClient,
    secret: config.secret
  });

  // Check the API secret key validity
  const apiSecretMiddleware = function(req, res, next) {
    if (!req.ganomede.secretMatches) {
      return sendError(new restifyErrors.UnauthorizedError('not authorized'), next);
    }
    next();
  };

  // Long Poll midlleware
  const longPollMiddleware = function(req, res, next) {
    if (res.headersSent) {
      return next();
    }

    const query = req.params.messagesQuery;

    return longPoll.add(query.username,
      () => queue.getMessages(query, function(err, messages) {
        if (err) {
          sendError(err, next);
        } else {
          res.json(messages);
          next();
        }
      }),
      function() {
        res.json([]);
        next();
    });
  };

  //
  // Endpoints
  //

  // Retrieve the list of messages for a user
  const getMessages = function(req, res, next) {
    const query:QueueQuery =
      {username: req.params.user.username};

    if (hasOwnProperty.call(req.query, 'after')) {
      query.after = +req.query.after;
      if (!isFinite(query.after)) {
        // || query.after < 0 (negative "after" allows to retrieve all message)
        const restErr = new restifyErrors.InvalidContentError('invalid content');
        return sendError(restErr, next);
      }
    }

    // load all recent messages
    queue.getMessages(query, function(err, messages) {
      if (err) {
        return sendError(err, next);
      }

      // if there's data to send, send it right away
      // also happens with special value after = -2
      if ((messages && messages.length > 0) || (query.after === -2)) {
        res.json(messages);
      }

      req.params.messagesQuery = query;
      next();
    });
  };

  // Post a new message to a user
  const postMessage = function(req, res, next) {
    // check that there is all required fields
    const {
      body
    } = req;
    if (!body.to || !body.from || !body.type || !body.data) {
      return sendError(new restifyErrors.InvalidContentError('invalid content'), next);
    }

    body.timestamp = Date.now();

    // add the message to the user's list
    return queue.addMessage(body.to, body, function(err?: Error, message?: Notification) {
      if (err) {
        return sendError(err, next);
      }
      if (!message)
        return sendError(new Error('message should be defined'), next);

      // If message has push object, it is also meant to be sent as
      // push notification.
      if (hasOwnProperty.call(message, 'push')) {
        addPushNotification(message);
      }

      const reply = {
        id: message.id,
        timestamp: message.timestamp
      };

      // notify user that he has a message and respond to request
      pubsub.publish(body.to);
      res.json(reply);
      next();
    });
  };

  return function(prefix:string, server:restify.Server) {
    if (prefix.length > 0 && prefix[0] !== '/') prefix = '/' + prefix;
    log.info('setup notifications api:', prefix);
    server.get(`${prefix}/auth/:authToken/messages`,
      authMiddleware, getMessages, longPollMiddleware);
    server.post(`${prefix}/messages`, apiSecretMiddleware, postMessage);
  };
};

export default notificationsApi;

// vim: ts=2:sw=2:et:

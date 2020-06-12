// import * as restify from 'restify';
import * as restifyErrors from 'restify-errors';
import * as redis from 'redis';
import * as AuthDB from 'authdb';
import authdbHelper from '../authdb-helper';
import Token from './token';
import TokenStorage from './token-storage';
import Queue from './queue';
import config from '../../config';
import log from '../log';
import { Notification } from '../types';

export interface PushApiOptions {
  tokenStorage?: TokenStorage;
  authdb?: any;
}

export default function(options?:PushApiOptions) {
  if (options == null) { options = {}; }
  const tokenStorage = options.tokenStorage || new TokenStorage(
    redis.createClient(
      config.pushApi.redisPort,
      config.pushApi.redisHost,
        {no_ready_check: true}
    )
  );

  const queue = new Queue(tokenStorage.redis, tokenStorage);

  const authdb = options.authdb || AuthDB.createClient({
    host: config.authdb.host,
    port: config.authdb.port
  });

  const authMiddleware = authdbHelper.create({
    authdbClient: authdb,
    secret: config.secret
  });

  const savePushToken = function(req, res, next) {
    if (!req.body || !req.body.app || !req.body.type || !req.body.value ||
           !Array.from(Token.TYPES).includes(req.body.type)) {
      return next(new restifyErrors.InvalidContentError);
    }

    const token = Token.fromPayload({
      username: req.params.user.username,
      app: req.body.app,
      type: req.body.type,
      value: req.body.value
    });

    return tokenStorage.add(token, function(err, added) {
      if (err) {
        log.error('Failed to add token', {
          err,
          token
        }
        );
        return next(new restifyErrors.InternalServerError);
      }

      res.send(200);
      return next();
    });
  };

  const api = (prefix, server) => {
    if (prefix.length > 0 && prefix[0] !== '/') prefix = '/' + prefix;
    log.info('setup push api:', prefix);
    server.post(`${prefix}/auth/:authToken/push-token`,
      authMiddleware, savePushToken);
  }

  api.addPushNotification = (message: Notification) => {
    queue.add(message);
  }

  return api;
};

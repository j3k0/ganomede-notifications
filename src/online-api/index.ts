import * as redis from 'redis';
import * as authdb from "authdb";
import authdbHelper from '../authdb-helper';
import * as restify from "restify";
import * as restifyErrors from "restify-errors";
import ListManager from './list-manager';
import config from '../../config';
import logMod from '../log';
const log = logMod.child({module: "online-api"});

export interface OnlineApiOptions {
  onlineList?: ListManager|any;
  authdbClient?: any;
};

const createApi = function(options?:OnlineApiOptions) {
  if (options == null) { options = {}; }
  const onlineList = options.onlineList || new ListManager(
    redis.createClient(
      config.onlineList.redisPort,
      config.onlineList.redisHost,
      {no_ready_check: true}
    ),

    {
      maxSize: config.onlineList.maxSize,
      invisibleUsernameRegExp: config.onlineList.invisibleUsernameRegExp
    }
  );

  // Populates req.params.user with value returned from authDb.getAccount()
  const authMiddleware = authdbHelper.create({
    authdbClient: options.authdbClient || authdb.createClient({
      host: config.authdb.host,
      port: config.authdb.port
    }),
    secret: config.secret
  });

  // Return list of usernames most recently online.
  const fetchList = function(req, res, next) {
    const listId = req.params != null ? req.params.listId : undefined;
    return onlineList.get(req.params.listId, function(err, list) {
      if (err) {
        log.error('fetchList() failed', {listId, err});
        return next(new restifyErrors.InternalServerError());
      }

      res.json(list);
      return next();
    });
  };

  // Adds user to the list and returns updated list.
  const updateList = function(req, res, next) {
    const listId = req.params != null ? req.params.listId : undefined;
    const profile = req.params != null ? req.params.user : undefined;

    return onlineList.add(listId, profile, function(err, newList) {
      if (err) {
        log.error('updateList() failed', {listId, err});
        return next(new restifyErrors.InternalServerError());
      }

      res.json(newList);
      return next();
    });
  };

  return function(prefix:string, server:restify.Server) {
    if (prefix.length > 0 && prefix[0] !== '/') prefix = '/' + prefix;
    log.info('setup online api:', prefix);
    // Fetch lists
    server.get(`${prefix}/online`, fetchList);
    server.get(`${prefix}/online/:listId`, fetchList);

    // Update lists
    const updateStack = [authMiddleware, updateList];
    server.post(`${prefix}/auth/:authToken/online`, updateStack);
    return server.post(`${prefix}/auth/:authToken/online/:listId`, updateStack);
  };
};

export default createApi;

// vim: ts=2:sw=2:et:

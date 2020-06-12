import * as redis from 'redis';
import * as authdb from "authdb";
import authdbHelper from '../authdb-helper';
import * as restify from "restify";
import * as restifyErrors from "restify-errors";
import ListManager from './list-manager';
import config from '../../config';
import logMod from '../log';
import { LastSeenClient, LastSeen } from './last-seen';
const log = logMod.child({module: "online-api"});

export interface OnlineApiOptions {
  onlineList?: ListManager;
  lastSeen?: LastSeenClient;
  authdbClient?: any;
};

const createApi = function(options?:OnlineApiOptions) {
  if (options == null) { options = {}; }
  const onlineList: ListManager = options.onlineList || new ListManager(
    redis.createClient(
      config.onlineList.redisPort,
      config.onlineList.redisHost,
      {no_ready_check: true}),
    {
      maxSize: config.onlineList.maxSize,
      invisibleUsernameRegExp: config.onlineList.invisibleUsernameRegExp
    }
  );

  const lastSeen: LastSeenClient = options.lastSeen || new LastSeenClient({
    redis: redis.createClient(
      config.onlineList.redisPort,
      config.onlineList.redisHost,
      {no_ready_check: true}
    )
  });

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

  const setup = function(prefix:string, server:restify.Server) {
    if (prefix.length > 0 && prefix[0] !== '/') prefix = '/' + prefix;
    log.info('setup online api:', prefix);
    // Fetch lists
    server.get(`${prefix}/online`, fetchList);
    server.get(`${prefix}/online/:listId`, fetchList);

    // Update lists
    const updateStack = [authMiddleware, updateList];
    server.post(`${prefix}/auth/:authToken/online`, updateStack);
    server.post(`${prefix}/auth/:authToken/online/:listId`, updateStack);

    // Retrieve user last seen date
    server.get(`${prefix}/lastseen/:usernames`, function(req:restify.Request, res:restify.Response, next:restify.Next) {
      const usernames = req.params.usernames;
      lastSeen.load(usernames.split(','), function(err: Error|null, reply: LastSeen|null): void {
        if (err) return next(err);
        res.json(reply);
        next();
      });
    });
  };

  setup.onUserRequest = function(username:string, callback:()=>void) {
    // store the last request time to redis
    lastSeen.save(username, new Date(), callback);
  };

  return setup;
};

export default createApi;

// vim: ts=2:sw=2:et:

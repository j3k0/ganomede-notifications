import log from '../log';
import { RedisClient } from 'redis';

// Stores list of users most recently online.
// Uses Redis' sorted set with score -timestamp of request.
// Options:
//   maxSize
//   prefix
//   invisibleUsernameRegExp
export class ListManager {

  redis: RedisClient;
  maxRedisIndex: number;
  prefix: string;
  invisibleUsernameRegExp: RegExp|null;

  constructor(redis, options) {
    if (options == null) { options = {}; }
    this.redis = redis;
    this.maxRedisIndex = options.maxSize;
    this.prefix = options.prefix || 'online-list';
    this.invisibleUsernameRegExp = options.invisibleUsernameRegExp || null;

    if (!this.redis) {
      throw new Error('OnlineList() requires a Redis client');
    }

    if (!isFinite(this.maxRedisIndex) || (this.maxRedisIndex < 0)) {
      throw new Error('OnlineList() requires options.maxSize to be Integer > 0');
    }
  }

  key(listId) {
    const id = listId || 'default';
    return `${this.prefix}:${id}`;
  }

  userVisible(profile) {
    if (!(profile != null ? profile.username : undefined)) {
      return false;
    }

    if (profile._secret) {
      return false;
    }

    if (this.invisibleUsernameRegExp) {
      const hidden = this.invisibleUsernameRegExp.test(profile.username);
      return !hidden;
    }

    return true;
  }

  add(listId, profile, callback) {
    if (!this.userVisible(profile)) {
      return this.get(listId, callback);
    }

    const key = this.key(listId);

    // add user or update his position
    // remove oldest users
    // fetch updated list
    return this.redis.multi()
      .zadd(key, -Date.now(), profile.username)
      .zremrangebyrank(key, this.maxRedisIndex, -1)
      .zrange(key, 0, -1)
      .exec(function(err, replies) {
        if (err) {
          log.error(`ListManager failed to update list ${listId}`, err);
          return callback(err);
        }

        return callback(null, replies[2]);
    });
  }

  get(listId, callback) {
    const key = this.key(listId);

    return this.redis.zrange(key, 0, -1, function(err, list) {
      if (err) {
        log.error(`ListManager failed to retrieve list ${listId}`, err);
        return callback(err);
      }

      return callback(null, list);
    });
  }
}

export default ListManager;
// vim: ts=2:sw=2:et:

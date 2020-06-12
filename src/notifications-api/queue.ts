import * as vasync from 'vasync';
import log from '../log';
import { RedisClient } from 'redis';
import { Notification } from '../types';

export interface QueueOptions {
  maxSize: number;
}

export class Queue {

  redis: RedisClient;
  maxRedisIndex: number;

  constructor(redis: RedisClient, options:QueueOptions) {
    this.redis = redis;
    this.maxRedisIndex = options.maxSize - 1; // redis' list is zero-based

    if (!this.redis) {
      throw new Error('Queue() requires a Redis client');
    }

    if (!isFinite(this.maxRedisIndex) || (this.maxRedisIndex < 0)) {
      throw new Error('Queue() requires options.maxSize to be Integer > 0');
    }
  }

  nextId(callback) {
    return this.redis.incr('@', function(err, id) {
      if (err) {
        log.error('Queue#nextId() failed',
          {err});
        return callback(err);
      }

      return callback(null, id);
    });
  }

  _addMessage(username, message, callback) {
    return this.redis.multi()
      .lpush(username, JSON.stringify(message))
      .ltrim(username, 0, this.maxRedisIndex)
      .exec(callback);
  }

  // Figures out message ID and adds message to user's queue
  // callback(err, message)
  addMessage(username, message, callback) {
    return vasync.waterfall([
      this.nextId.bind(this),
      (id, cb) => {
        message.id = id;
        return this._addMessage(username, message, function(err, replies) {
          if (err) {
            log.error('Queue#addMessage() failed', {
              err,
              replies
            }
            );
            return cb(err);
          }

          return cb(null, message);
        });
      }
    ], callback);
  }

  // callback(err, messages)
  getMessages(username: string, callback: (err:Error|null, messages:Array<Notification>|null)=>void);
  getMessages(query: QueueQuery, callback: (err:Error|null, messages:Array<Notification>|null)=>void);
  getMessages(queryOrUsername: QueueQuery|string, callback: (err:Error|null, messages:Array<Notification>|null)=>void) {
      const query: QueueQuery = typeof queryOrUsername === 'string'
    ? {username: queryOrUsername}
    : queryOrUsername;
    
    return this.redis.lrange(query.username, 0, -1, function(err, messages) {
      if (err) {
        log.error({ err, query },'Queue#getMessages() failed');
        return callback(err, null);
      }
      callback(null, Queue.filter(query, messages));
    });
  }

  static filter(query: QueueQuery, messages): Array<Notification> {
    const ret: Array<Notification> = [];

    try {
      // if a "after" filter has been set, only returns messages
      // more recent than the provided id.
      let m, msg;
      if ((query != null ? query.after : undefined) != null) {
        for (m of Array.from(messages)) {
          msg = JSON.parse(m);
          // notes:
          //  - ids are auto-incremental
          //  - message are ordered newest to oldest
          // so it's valid to break when "after" has been found.
          if (msg.id === query.after) {
            break;
          }
          if (msg.id) {
            ret.push(msg);
          }
        }
      } else {
        // no filter, send the whole array
        for (m of Array.from(messages)) {
          msg = JSON.parse(m);
          if (msg.id) {
            ret.push(msg);
          }
        }
      }
    } catch (error) {
      // ignore JSON.parse() exceptions,
      // hopefully we parsed the most recent messages
      if (error instanceof SyntaxError) {
        log.warn({
          query,
          messages,
          error
        }, 'Query.filter() failed JSON.parse() step');
      }

      throw error;
    }

    return ret;
  }
}

export interface QueueQuery {
  username: string;
  after?: number;
};

export default Queue;
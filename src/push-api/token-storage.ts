import { Token, TokenType } from './token';
import { RedisClient } from 'redis';
import * as vasync from 'vasync';
import config from '../../config';
import redisMod from 'redis';

export type TokenCallback = (err:Error|null|undefined, tokens?:Token[]) => void;

// Within redis hash we have
//  #{type:device}: value
const toHashSubkey = token => `${token.type}:${token.device}`;
const fromHashSubkey = function(subkey, value) {
  const parts = subkey.split(':');
  return {
    type: parts[0],
    device: parts[1],
    value
  };
};

class TokenStorage {
  redis:RedisClient;

  constructor(redis:RedisClient) {
    this.redis = redis;
  }

  // Adds token to redis.
  // callback(err, added)
  add(token:Token, callback) {
    return this.redis.hset(token.key, toHashSubkey(token), token.value, (err, reply) => // 1 for adding
    // 0 for updating
    callback(err, reply === 1));
  }

  // Retrieves username's tokens for particular app
  get(username:string, app:string, callback:TokenCallback) {
    const key = Token.key(username, app);

    return this.redis.hgetall(key, function(err, tokens) {
      if (err) {
        return callback(err);
      }

      let ret:Array<Token> = [];
      if (tokens) {
        ret = Object.keys(tokens).map(subkey => new Token(key, fromHashSubkey(subkey, tokens[subkey])));
      }

      return callback(null, ret);
    });
  }

  // Scan redis db @from for push tokens in old format,
  // upgrade them to new format.
  _upgrade(from, callback) {
    const r = this.redis;
    if (!from) { from = 0; }
    const newPrefix = Token.key('', '').slice(0, -2);
    const oldPrefix = 'notifications:push-tokens';
    const mask = `${oldPrefix}:*`;
    // const upgradedTokens = {};

    console.log('working with', {db: from, newPrefix, oldPrefix, mask});

    return vasync.waterfall([
      // switch redis db
      cb => r.select(from, cb),
      // get keys of old sets
      function(reply, cb) {
        console.log('looking for keys to upgrade…');
        return r.keys(mask, function(err, keys) {
          if (err) { return cb(err); }
          const oldKeys = keys.filter(key => -1 === key.indexOf(newPrefix));
          return cb(null, oldKeys);
        });
      },
      // convert old values to new format
      function(keys, cb) {
        console.log(`converting ${keys.length} keys…`);
        const tokensToCreate:Array<Token> = [];

        const findFirst = function(type:TokenType, set:Array<string>):string|undefined {
          let ret:string|undefined;
          set.some(function(item) {
            if (item.indexOf(type) === 0) {
              ret = item;
              return true;
            }
          });
          return ret;
        };

        const upgradeKey = (key, cb) => r.smembers(key, function(err, tokens) {
          if (err) { return cb(err); }
          const apn:string|undefined = findFirst('apn', tokens);
          const gcm:string|undefined = findFirst('gcm', tokens);
          const newKey:string = key.replace(oldPrefix, newPrefix);

          if (apn) {
            tokensToCreate.push(new Token(newKey, {
              type: 'apn',
              value: apn.slice('apn'.length + 1)
            }));
          }

          if (gcm) {
            tokensToCreate.push(new Token(newKey, {
              type: 'gcm',
              value: gcm.slice('gcm'.length + 1)
            }));
          }

          return cb();
        });

        return vasync.forEachParallel({
          inputs: keys,
          func: upgradeKey
        }, err => cb(err, tokensToCreate));
      },
      // save converted tokens into redis
      function(tokensToCreate, cb) {
        if (tokensToCreate.length === 0) {
          console.log(`db ${from} has no tokens with prefix ${oldPrefix}`);
          return cb();
        }

        console.log(`saving ${tokensToCreate.length} upgraded tokens…`);

        const multi = r.multi();

        tokensToCreate.forEach(token => multi.hset(token.key, toHashSubkey(token), token.value));

        return multi.exec(cb);
      }
    ], callback);
  }
}

export default TokenStorage;

if (!module.parent) {
  const redis = redisMod.createClient(
    config.pushApi.redisPort,
    config.pushApi.redisHost
  );

  const from = process.env.DB_FROM;

  process.on('beforeExit', redis.quit.bind(redis));

  new TokenStorage(redis)._upgrade(from, function(err, results) {
    if (err) {
      console.error('failed', err);
      return process.exit(1);
    }

    const nUpdated = results.filter(reply => reply === 0).length;
    const nCreated = results.filter(reply => reply === 1).length;

    console.log(`Done! Upgraded ${results.length} tokens:`, {nUpdated, nCreated});
    return process.exit(0);
  });
}

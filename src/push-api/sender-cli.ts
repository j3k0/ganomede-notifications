// Sending push notifications from redis queue.

import * as vasync from 'vasync';
import * as stream from 'stream';
import * as redis from 'redis';
import config from '../../config';
import Token from './token';
import TokenStorage from './token-storage';
import { Sender, Senders } from './sender';
import Queue from './queue';
import logMod from '../log';
const log = logMod.child({SenderCli:true});

class Producer extends stream.Readable {
  
  queue: Queue;

  constructor(queue: Queue) {
    super({objectMode: true, highWaterMark: config.pushApi.cli.readAhead});
    this.queue = queue;
  }

  _getTask(callback) {
    return this.queue.get((err, task) => {
      if (err) {
        log.error({err}, 'Failed to retrieve task');
        return callback(err, null);
      }

      // If no tokens, skip notification, and _getTask() again for a new item.
      if (task && (task.tokens.length === 0)) {
        log.info({to: task.notification.to}, '[skip] No tokens for user');
        return process.nextTick(this._getTask.bind(this, callback));
      }

      if (task) {
        log.debug({id:task.notification.id}, 'read');
      } else {
        log.debug('queue is empty');
      }

      return callback(null, task || null);
    });
  }

  _read(size) {
    return this._getTask((err, task) => {
      if (err) {
        this.emit('error', err);
      }

      return this.push(task);
    });
  }
}

class Consumer extends stream.Writable {
  sender: Sender;
  state: {
    queued: number;
    finished: number;
    maxDiff: number;
    processedCallbacks: Array<()=>void>;
  };

  constructor(sender: Sender) {
    super({objectMode: true, highWaterMark: config.pushApi.cli.parallelSends});
    this.sender = sender;

    this.state = {
      queued: 0,
      finished: 0,
      maxDiff: config.pushApi.cli.parallelSends,
      processedCallbacks: []
    };

    this.sender.on(Sender.events.PROCESSED, (senderType, notifId, token) => {
      this.state.finished += 1;
      log.info(`${senderType} processed ${notifId} for ${token}`);
      log.debug({state:this.state}, `${senderType} processed ${notifId} for ${token}`);

      const canQueueMore = (this.state.queued - this.state.finished) <= this.state.maxDiff;
      if (canQueueMore) {
        log.debug({state:this.state}, 'can queue more');
        const fn = this.state.processedCallbacks.pop();
        if (fn) {
          return fn();
        }
      }
    });

    //@sender.on Sender.events.SUCCESS, (senderType, info) ->
    //  debug({info:info}, "#{senderType} succeeded")

    this.sender.on(Sender.events.FAILURE, (senderType, err, notifId, token) => log.error({err},
      `${senderType} failed to send ${notifId} for ${token}`));
  }

  _write(task, encoding, processed) {
    this.state.queued += task.tokens.length;
    this.state.processedCallbacks.push(processed);
    log.debug({id:task.notification.id, state:this.state}, 'written');
    return this.sender.send(task);
  }
}

const main = function(testing) {
  let apnSender, gcmSender;
  const client = redis.createClient(
    config.pushApi.redisPort, config.pushApi.redisHost
  );

  const storage = new TokenStorage(client);
  const queue = new Queue(client, storage);

  apnSender = new Sender.ApnSender({
    cert: config.pushApi.apn.cert,
    key: config.pushApi.apn.key,
    buffersNotifications: false,
    maxConnections: config.pushApi.apn.maxConnections
  });

  gcmSender = new Sender.GcmSender(
    config.pushApi.gcm.apiKey || ''
  );

  const senders:Senders = {
    apn: apnSender,
    gcm: gcmSender
  };
  const sender = new Sender(senders);
  const producer = new Producer(queue);
  const consumer = new Consumer(sender);

  // Keep track of closed sockets.
  const quitters = {
    redis: false,
    apn: false
  };
      
  const tryToExit = function() {
    log.debug({quitters}, 'trying to exit');
    if (quitters.redis && quitters.apn) {
      return process.exit(0);
    } else {
      // Redis usually shuts down nicely, but APN might need some time,
      // give it that, and force exit if it won't play nicely.
      return setTimeout(function() {
        log.debug({quitters}, 'forced exit');
        return process.exit(0);
      }
      , 10000);
    }
  };

  // redis queue is empty
  producer.on('end', function() {
    client.quit();
    return client.once('end', function() {
      quitters.redis = true;
      return tryToExit();
    });
  });

  // all the tasks are enqueued to be sent or sent
  consumer.on('finish', () => apnSender.close(function() {
    quitters.apn = true;
    return tryToExit();
  }));

  // Start callbacking
  const start = function(err?:Error) {
    if (err) {
      log.error({err}, 'start() called with error');
      return process.exit(1);
    }

    return producer.pipe(consumer);
  };

  // Dump 100 notifications to redis and token for user.
  const populateRedis = function(callback) {
    const objects = __range__(1, 100, true).map(i => JSON.stringify({
      to: 'alice',
      id: i,
      push: {
        app: 'app',
        title: ['test'],
        message: ['test-msg']
      }
    }));

    const token = Token.fromPayload({
      username: 'alice',
      app: 'app',
      type: 'apn',
      value: process.env.TEST_APN_TOKEN || '',
    });

    const tokenGcm = Token.fromPayload({
      username: 'alice',
      app: 'app',
      type: 'gcm',
      value: process.env.TEST_GCM_TOKEN || '',
    });

    const args = [config.pushApi.notificationsPrefix].concat(objects);
    const multi = client.multi();
    multi.flushdb();
    multi.lpush.apply(multi, args);
    return multi.exec(function(err) {
      if (err) {
        return callback(err);
      }

      const tokensToAdd = [token, tokenGcm].map(t => storage.add.bind(storage, t));

      return vasync.parallel({funcs: tokensToAdd}, function(err, results) {
        if (err) {
          return callback(err);
        }

        if (!results.successes.every(ret => ret === true)) {
          return callback(new Error('Not every token was added'));
        }

        return callback();
      });
    });
  };

  if (testing) { return populateRedis(start); } else { return start(); }
};

if (!module.parent) {
  main(process.env.hasOwnProperty('TEST_APN_TOKEN'));
}

function __range__(left, right, inclusive) {
  let range:Array<number> = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}
import * as vasync from 'vasync';
import {RedisClient} from 'redis';
import log from '../log';

export interface PubSubOptions {
  publisher:RedisClient;
  subscriber:RedisClient;
  channel:string;
}

export type PubSubHandler = (channel:string, username:string) => void;
export type PubSubCallback = (channel:string, n:number) => void;

export class PubSub {
  pub:RedisClient;
  sub:RedisClient;
  channel:string;
  listening:Boolean;
  constructor(pubsub:PubSubOptions) {
    this.pub = pubsub.publisher;
    this.sub = pubsub.subscriber;
    this.channel = pubsub.channel;
    this.listening = false;

    if (!this.pub) {
      throw new Error('PubSub() requires pubsub.pub to be a Redis client');
    }
    if (!this.sub) {
      throw new Error('PubSub() requires pubsub.sub to be a Redis client');
    }
    if (this.pub === this.sub) {
      // while in subscription mode, redis client can't send other commands,
      // that's why we need anther connection
      throw new Error('PubSub() requires pubsub.pub != pubsub.sub');
    }
    if (!this.channel) {
      throw new Error('PubSub() requires pubsub.channel to be a nonempty string');
    }
  }

  // callback(channel, nRecievers)
  publish(data, callback?) {
    return this.pub.publish(this.channel, data, callback);
  }

  // callback(channel, count)
  // Not sure what count is. Not sure if this is callable multiple times.
  subscribe(handler:PubSubHandler, callback?:PubSubCallback) {
    this.sub.on('message', handler);

    if (!this.listening) {
      this.listening = true;
      this.sub.subscribe(this.channel);
      if (callback) {
        return this.sub.once('subscribe', callback);
      }
    } else {
      log.warn({channel: this.channel},
        `PubSub#subscribe() called multiple times. Make sure you know what you are doing!`);

      if (callback) {
        process.nextTick(callback.bind(null, this.channel, 1));
      }
    }
  }

  quit(callback) {
    return vasync.parallel({
      funcs: [
        this.pub.quit.bind(this.pub),
        this.sub.quit.bind(this.sub)
      ]
    }, callback);
  }
}


export default PubSub;

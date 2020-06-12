import { Callback, RedisClient } from 'redis';

export interface LastSeenOptions {
    redis: RedisClient;
};

export interface LastSeen {
    [username: string]: Date;
}

function parse(usernames:Array<string>, values:Array<string>): LastSeen {
    const ret: LastSeen = {};
    if (!usernames || !values || usernames.length !== values.length) return ret;
    for (let i: number = 0; i < usernames.length; ++i)
        ret[usernames[i]] = new Date(values[i]);
    return ret;
}

export type LastSeenLoadCallback = Callback<LastSeen>;
export type LastSeenSaveCallback = Callback<"OK"|undefined>;

function toKey(username:string) {
    return 'lastseen:' + username;
}

export class LastSeenClient {

    private redis: RedisClient;

    constructor(options: LastSeenOptions) {
        if (options.redis)
            this.redis = options.redis;
        else
            throw new Error('OnlineList() requires a Redis client');
    }

    load(usernames: Array<string>, callback: LastSeenLoadCallback) {
        this.redis.mget(usernames.map(toKey), function(err: Error|null, reply: Array<string>) {
            callback(err, parse(usernames, reply));
        });
    }

    save(username: string, value: Date, callback: LastSeenSaveCallback) {
        this.redis.set(toKey(username), value.toISOString(), 'EX', 3600, callback);
    }
}

export function createClient(options: LastSeenOptions): LastSeenClient {
    return new LastSeenClient(options);
}

export default createClient;
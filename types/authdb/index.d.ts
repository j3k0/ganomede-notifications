declare module 'authdb' {
    import { RedisClient } from "redis";

    // import { createClient } from 'authdb';

    interface AuthDBOptions {
        redisClient?: RedisClient;
        port?: number;
        host?: string;
    }

    interface AuthDBClient {
        /// Retrieve an user account from authentication token
        ///
        /// cb(err, account) will be called.
        ///
        /// account will be null if no account is found, i.e.
        /// user has to login again.
        getAccount (token: string, cb: (err:Error|string|null, account: object|null) => void);

        /// Removes an account into the authentication database
        removeAccount (token: string, cb: () => void);
        
        /// Adds an account into the authentication database
        /// cb(err, reply) will be called with result.
        addAccount (token: string, account: object, cb: () => void);
    }

    function createClient(options?:AuthDBOptions): AuthDBClient;
}
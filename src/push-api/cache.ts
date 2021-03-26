import redis from 'redis';

const port = parseInt(process.env.REDIS_CACHE_PORT || '6379');
const host = process.env.REDIS_CACHE_HOST || '127.0.0.1';
const client = redis.createClient(port, host);

export async function set(key:string, value:string, ttl:number):Promise<void> {
  return new Promise((resolve) => {
    client.setex(key, ttl, value, _ => {
      resolve();
    });
  });
}

export async function get(key:string):Promise<string | null> {
  return new Promise((resolve) => {
    client.get(key, (err, value) => {
      // ignore errors.
      resolve(value || null);
    });
  });
}

export default {
  get, set
};
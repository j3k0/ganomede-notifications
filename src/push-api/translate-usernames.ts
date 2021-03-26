import * as fetch from 'node-fetch';
import config from '../../config';
// import NodeCache from 'node-cache';
import logMod from '../log';
import Cache from './cache';

const log = logMod.child({module: "translate-username"});
const directoryURL = config.directory.url;

const SAME_AS_KEY = '_';

function fetchName(userId: string, callback: (name: string | null) => void): void {
  if (!directoryURL) {
    return callback(null);
  }
  fetch(`${directoryURL}/users/id/${encodeURIComponent(userId)}`)
  .then(res => res.json())
  .then(function(json) {
    log.debug({directoryURL,userId,json}, 'fetch profile from directory');
    const name = json.aliases?.name;
    callback(name || null);
  })
  .catch(err => {
    log.info({directoryURL,userId,err}, '[failed] fetch profile from directory: ' + err?.message);
    callback(null);
  });
};

export async function translateUsername(userId: string): Promise<string> {
  return new Promise(async (resolve) => {
    const cached: string | null = await Cache.get('u:' + userId);
    if (cached && typeof cached === 'string') {
      log.debug(`translated username [cached]: ${userId} > ${cached}`);
      if (cached === SAME_AS_KEY)
        resolve(userId);
      else
        resolve(cached);
    }
    else {
      fetchName(userId, (name) => {
        log.debug(`translated username [fetched]: ${userId} > ${name || '<empty>'}`);
        if (name) {
          Cache.set('u:' + userId, name === userId ? SAME_AS_KEY : name, 3600);
          resolve(name);
        }
        else {
          resolve(userId);
        }
      });
    }
  });
}

import * as fetch from 'node-fetch';
import config from '../../config';
import logMod from '../log';
import Cache from './cache';

const log = logMod.child({module: "user-locale"});

const usermetaURL = config.usermeta.url;

const fetchUsermetas = function(userId, callback) {
  userId = encodeURIComponent(userId);
  return fetch(`${usermetaURL}/${userId}/location,locale`)
  .then(res => res.json())
  .then(function(json) {
    if (userId === 'kago042') {
      log.info({ json, userId }, 'Metadata fetched');
    }
    return callback(json[userId]);})
  .catch(err => callback());
};

const formatLocale = locale => locale.slice(0, 2).toLowerCase();

const localeFromLocation = function(location?:string):string {
  if (!location) {
    return 'en';
  }
  if (location.indexOf('France') >= 0) {
    return 'fr';
  }
  if (location.indexOf('Germany') >= 0) {
    return 'de';
  }
  if (location.indexOf('Netherlands') >= 0) {
    return 'nl';
  }
  if (location.indexOf('Spain') >= 0) {
    return 'es';
  }
  if (location.indexOf('Portugal') >= 0) {
    return 'pt';
  }
  if (location.indexOf('Poland') >= 0) {
    return 'pl';
  }
  return 'en';
};

class UserLocale {
  static async fetch(userId:string, callback) {

    const cached: string | null = await Cache.get('l:' + userId);
    if (cached && typeof cached === 'string') {
      log.debug(`user locale [cached]: ${userId} = "${cached}"`);
      callback(cached);
      return;
    }

    fetchUsermetas(
      userId,
      function(data) {
        let locale:string|undefined = undefined;
        if (!data) {
          locale = 'en';
          log.debug(`user locale [fetched]: ${userId} = "en" from default`);
        } else if (data.locale) {
          locale = formatLocale(data.locale);
          if (locale) Cache.set('l:' + userId, locale, 3600);
          log.debug(`user locale [fetched]: ${userId} = "${locale}"`);
        } else {
          locale = localeFromLocation(data.location);
          if (locale) Cache.set('l:' + userId, locale, 3600);
          log.debug(`user locale [fetched]: ${userId} = "${locale}" from location`);
        }
        callback(locale);
    });
  }
}

export default UserLocale;

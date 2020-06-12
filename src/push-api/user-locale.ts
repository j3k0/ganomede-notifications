import * as fetch from 'node-fetch';

import config from '../../config';
import logMod from '../log';
const log = logMod.child({module: "user-locale"});

const usermetaURL = config.usermeta.url;

const fetchUsermetas = function(username, callback) {
  username = encodeURIComponent(username);
  return fetch(`${usermetaURL}/${username}/location,locale`)
  .then(res => res.json())
  .then(function(json) {
    if (username === 'kago042') {
      log.info({json, username}, 'Metadata fetched');
    }
    return callback(json[username]);})
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
  static fetch(username:string, callback) {
    fetchUsermetas(
      username,
      function(data) {
        if (!data) {
          callback('en');
        } else if (data.locale) {
          callback(formatLocale(data.locale));
        } else {
          callback(localeFromLocation(data.location));
        }
    });
  }
}

export default UserLocale;

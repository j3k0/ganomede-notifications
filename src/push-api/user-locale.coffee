# https://prod.ggs.ovh/usermeta/v1/:username/locale
# https://prod.ggs.ovh/usermeta/v1/:username/location

fetch = require('node-fetch')
config = require '../../config'
log = require('../log').child(module: "user-locale")

usermetaURL = config.usermeta.url

fetchUsermetas = (username, callback) ->
  username = encodeURIComponent(username)
  fetch("#{usermetaURL}/#{username}/location,locale")
  .then((res) -> res.json())
  .then((json) ->
    if username == 'kago042'
      log.info {json, username}, 'Metadata fetched'
    callback(json[username]))
  .catch((err) -> callback())

formatLocale = (locale) ->
  return locale.slice(0, 2).toLowerCase()

localeFromLocation = (location) ->
  if not location
    return 'en'
  if location.indexOf('France') >= 0
    return 'fr'
  if location.indexOf('Germany') >= 0
    return 'de'
  if location.indexOf('Netherlands') >= 0
    return 'nl'
  if location.indexOf('Spain') >= 0
    return 'es'
  if location.indexOf('Portugal') >= 0
    return 'pt'
  if location.indexOf('Poland') >= 0
    return 'pl'
  return 'en'

class UserLocale
  @fetch: (username, callback) ->
    fetchUsermetas(
      username,
      (data) ->
        if data.locale
          callback(formatLocale(data.locale))
        else
          callback(localeFromLocation(data.location))
    )

module.exports = UserLocale

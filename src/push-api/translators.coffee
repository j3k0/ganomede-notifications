# translator is a function that accepts array of translatables
# and returns array of successful translations
# (see push-translator.coffee for details on objects).
#
# !!! IMPORTANT !!!
# Translators must never fail (log error-d items and skip them).
# Translators must always be async (setImmediate stuff if needed).
#
# arg types are of format "#{translatorId}:#{specific-info}". Exported object
# is keyed with TranslatorIDs and push-translator will use it to look up
# translators. For example, all the `directory:name` entries will
# be grouped into single array and passed to a function exported under
# `directory` key, like this:
#
#   require('./translatros')['directory'](translatabesArray, callback)
#
# It is translators job to correctly regroup all the translatables and
# issue appropriate number of requests.
#
# If translator is not found in exported objects, nothing will get translated,
# and original string will make it into resulting object.

util = require 'util'
async = require 'async'
lodash = require 'lodash'
log = require '../log'

# TODO
# push this out so we can td.replace net calls
deps = require './translators-deps'

hasOwnProperty = (obj, name) -> Object.prototype.hasOwnProperty.call(obj, name)
ignoreError = (fn) -> (args..., callback) ->
  cb = (err, results...) -> callback.call(this, null, results...)
  fn.call(this, args..., cb)

fetchProfile = ignoreError (userId, callback) ->
  deps.directoryClient.byId {id: userId}, (err, profile) ->
    if (err)
      log.error('Failed to user profile', {userId}, err)
      return callback(err)

    callback(null, profile)

directoryIter = (translatables, userId, callback) ->
  fetchProfile userId, (err, profile) ->
    if err
      return callback(err)

    translations = translatables
      .map (translatable) ->
        alias = translatable.type.slice(translatable.type.indexOf(':') + 1)
        hasAlias = profile?.aliases?[alias]?

        if !hasAlias
          log.info('User missing alias %j', {userId, alias})
          return null

        return translatable.translation(profile.aliases[alias])

    callback(null, translations)

directoryFinalizer = (callback) -> (err, result) ->
  successes = lodash
    .flatten(Object.values(result))
    .filter (t) -> !!t

  callback(null, successes)

directory = (translatables, callback) ->
  async.mapValues(
    lodash.groupBy(translatables, 'value'), # group by userId
    directoryIter,
    directoryFinalizer(callback)
  )

module.exports = {
  directory
}

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
log = require '../log'

# TODO
# push this out so we can td.replace net calls
deps = require './translators-deps'

hasOwnProperty = (obj, name) -> Object.prototype.hasOwnProperty.call(obj, name)
ignoreError = (fn) -> (args..., callback) ->
  cb = (err, results...) -> callback.call(this, null, results...)
  fn.call(this, args..., cb)

lookupSingleAlias = ignoreError (userId, alias, callback) ->
  deps.directoryClient.byId {id: userId}, (err, profile) ->
    if (err)
      log.error('Failed to lookup alias for user', {userId, alias}, err)
      return callback(err)

    hasAlias = profile?.aliases?[alias]?
    if (!hasAlias)
      error = new Error(util.format('User missing alias %j', {userId, alias}))
      log.info(error)
      return callback(error)

    callback(null, profile.aliases[alias])

directoryIter = (translatable, callback) ->
  userId = translatable.value
  alias = translatable.type.slice(translatable.type.indexOf(':') + 1)
  lookupSingleAlias userId, alias, (err, aliasValue) ->
    if err
      return callback(err)

    if aliasValue
      return callback(null, translatable.translation(aliasValue))

    callback(null, undefined)

directoryFinalizer = (callback) -> (err, translations) ->
  successes = translations.filter (t) -> !!t
  callback(null, successes)

directory = (translatables, callback) ->
  async.map(
    translatables,
    directoryIter,
    directoryFinalizer(callback)
  )

module.exports = {
  directory
}

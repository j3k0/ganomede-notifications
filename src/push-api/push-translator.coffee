assert = require 'assert'
lodash = require 'lodash'
async = require 'async'
log = require '../log'
translators = require './translators'

PUSH_FIELDS_TO_CHECK = ['title', 'message']

defaultTranslate = (translatables, cb) ->
  setImmediate(cb, null, [])

concatOf = (object, iteratee, callback) ->
  async.concat(
    Object.entries(object),
    ([key, value], cb) -> iteratee(key, value, cb)
    callback
  )

class PushTranslator
  constructor: () ->

  # callback(null, translated)
  # error is always null!
  #
  # TODO
  # probably accep only push prop and not whole notification!
  process: (notification, callback) ->
    push = new PushTranslator.PushObject(notification.push)

    @translate push.translatables(), (err, translations) ->
      # TODO
      # DO NOT FAIL OKAY PLEASE (assert for now)
      assert.strictEqual(err, null)

      notificationWithTranslatedPush = Object.assign(
        {},
        notification,
        {push: push.translatedUsing(translations)}
      )

      callback(null, notificationWithTranslatedPush)

  translate: (translatables, callback) ->
    jobs = lodash.groupBy translatables, (translatable) ->
      {type} = translatable
      requiredTranslator = type.slice(0, type.indexOf(':'))
      return requiredTranslator

    concatOf(
      jobs,
      (translatorId, translatables, cb) ->
        translateFn = translators[translatorId] || defaultTranslate
        translateFn(translatables, cb)
      callback
    )

  class @PushObject
    constructor: (@push) ->

    translatables: () ->
      result = []

      PUSH_FIELDS_TO_CHECK.forEach (field) =>
        values = @push[field].slice(1)
        types = @push["#{field}ArgsTypes"]
        translatables = []

        # Some *ArgsTypes might be missing.
        unless Array.isArray(types)
          return

        for value, index in values
          type = types[index]

          if type.includes(':')
            translatables.push(new PushTranslator.Translatable({
              field,
              index: index + 1, # because values are slice(1)
              value,
              type
            }))

        result = result.concat(translatables)

      return result

    translatedUsing: (translations) ->
      translated = lodash.cloneDeep(@push)

      for tr in translations
        {field, index} = tr.translatable
        translated[field][index] = tr.value

      return translated

  class @Translatable
    constructor: ({@field, @index, @value, @type}) ->
    translation: (translatedValue) -> new PushTranslator.Translation(
      this,
      translatedValue
    )

  class @Translation
    constructor: (@translatable, @value) ->

module.exports = PushTranslator

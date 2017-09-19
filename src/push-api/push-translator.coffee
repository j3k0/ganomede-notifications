assert = require 'assert'
lodash = require 'lodash'
async = require 'async'
log = require '../log'
translators = require './translators'

PUSH_FIELDS_TO_CHECK = ['title', 'message']
TRANSLATABLE_TYPES = ['directory:name']

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
  process: (notification, callback) ->
    push = new PushTranslator.PushObject(notification.push)

    @translate push.translatables(), (err, translations) ->
      # TODO
      # DO NOT FAIL OKAY PLEASE (assert for now)
      assert.strictEqual(err, null)
      callback(null, push.translatedUsing(translations))

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

        for value, index in values
          type = types[index]

          if (TRANSLATABLE_TYPES.includes(type))
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

  class @Translation
    constructor: (@translatable, @value) ->

module.exports = PushTranslator

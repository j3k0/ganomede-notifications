expect = require 'expect.js'
lodash = require 'lodash'
deepFreeze = require 'deep-freeze-strict'
PushTranslator = require '../../src/push-api/push-translator'
{PushObject, Translatable} = PushTranslator

describe 'PushTranslator', () ->
  pushData = deepFreeze({
    title: ["new_message", "bob", "sent you a message."],
    titleArgsTypes: ["directory:name", "string"],
    message: ["message_body", "Hello, ", "alice", "nice to see you!"],
    messageArgsTypes: ["string", "directory:name", "string"]
  })

  expectedTranslatables = deepFreeze([
    {field: 'title', index: 1, value: 'bob', type: 'directory:name'},
    {field: 'message', index: 2, value: 'alice', type: 'directory:name'}
  ].map (obj) -> new Translatable(obj))

  translations = deepFreeze(expectedTranslatables.map (translatable) ->
    return translatable.translation("tr(#{translatable.value})")
  )

  describe '#process()', () ->
    it 'tests pending (is okay, this one is just plumbing anyways)'

  describe '#translate()', () ->
    it 'tests pending (pretty awkward method, redo it later)'

  describe 'PushObject', () ->
    describe '#translatables()', () ->
      it 'returns stuff to translate with proper indexes', () ->
        push = new PushObject(pushData)
        expect(push.translatables()).to.eql(expectedTranslatables)

      it 'works when *ArgsTypes is missing for some fields', () ->
        push = new PushObject(lodash.omit(pushData, 'messageArgsTypes'))
        expect(push.translatables()).to.eql(expectedTranslatables.slice(0, 1))

    describe '#translatedUsing()', () ->
      it 'accepts a bunch of `Translation`s and returns translated push', () ->
        push = new PushObject(pushData)

        expect(push.translatedUsing(translations)).to.eql({
          title: ["new_message", "tr(bob)", "sent you a message."],
          titleArgsTypes: ["directory:name", "string"],
          message: ["message_body", "Hello, ", "tr(alice)", "nice to see you!"],
          messageArgsTypes: ["string", "directory:name", "string"]
        })

expect = require 'expect.js'
PushTranslator = require '../../src/push-api/push-translator'

describe 'PushTranslator', () ->
  describe '#process()', () ->
    it 'returns the value it has received', (done) ->
      translator = new PushTranslator()
      ref = {}

      translator.process ref, (err, translated) ->
        expect(err).to.be(null)
        expect(translated).to.be(ref)
        done()

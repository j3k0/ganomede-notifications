td = require 'testdouble'
expect = require 'expect.js'
{Translatable, Translation} = require '../../src/push-api/push-translator'

describe 'translators', () ->
  translators = null
  translatorsDeps = null

  beforeEach () ->
    translatorsDeps = td.replace '../../src/push-api/translators-deps'
    translators = require '../../src/push-api/translators'

  afterEach () -> td.reset()

  describe 'directory:*', () ->
    it 'translates single alias', (done) ->
      t = new Translatable({
        field: 'something',
        index: 0,
        value: 'bob',
        type: 'ganomede:name'
      })

      td.when(translatorsDeps.directoryClient.byId({id: 'bob'}, td.callback))
        .thenCallback(null, {aliases: {name: 'Magnificent Bob'}})

      translators.directory [t], (err, translations) ->
        expect(err).to.be(null)
        expect(translations).to.eql([
          new Translation(t, 'Magnificent Bob')
        ])
        done()

    it 'translates multiple aliases for 1 user in single call', (done) ->
      t1 = new Translatable({
        field: 'something',
        index: 0,
        value: 'bob',
        type: 'ganomede:name'
      })

      t2 = new Translatable({
        field: 'something',
        index: 1,
        value: 'bob',
        type: 'ganomede:email'
      })

      td.when(translatorsDeps.directoryClient.byId({id: 'bob'}, td.callback))
        .thenCallback(null, {
          aliases: {
            name: 'Magnificent Bob',
            email: 'bob@magnificent-creatures.mail'
          }
        })

      translators.directory [t1, t2], (err, translations) ->
        expect(err).to.be(null)
        expect(translations).to.eql([
          new Translation(t1, 'Magnificent Bob')
          new Translation(t2, 'bob@magnificent-creatures.mail'),
        ])
        done()

    it 'translates multiple aliases from multiple users', (done) ->
      t1 = new Translatable({
        field: 'something',
        index: 0,
        value: 'alice',
        type: 'ganomede:name'
      })

      t2 = new Translatable({
        field: 'something',
        index: 1,
        value: 'bob',
        type: 'ganomede:name'
      })

      td.when(translatorsDeps.directoryClient.byId({id: 'alice'}, td.callback))
        .thenCallback(null, {aliases: {name: 'Alice of the Wonderland'}})

      td.when(translatorsDeps.directoryClient.byId({id: 'bob'}, td.callback))
        .thenCallback(null, {aliases: {name: 'Magnificent Bob'}})

      translators.directory [t1, t2], (err, translations) ->
        expect(err).to.be(null)
        expect(translations).to.eql([
          new Translation(t1, 'Alice of the Wonderland')
          new Translation(t2, 'Magnificent Bob'),
        ])
        done()

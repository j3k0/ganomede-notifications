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
        expect(td.explain(translatorsDeps.directoryClient.byId))
          .to.have.property('callCount', 1)
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
        value: 'alice',
        type: 'ganomede:name'
      })

      t3 = new Translatable({
        field: 'something',
        index: 2,
        value: 'bob',
        type: 'ganomede:name'
      })

      t4 = new Translatable({
        field: 'something',
        index: 3,
        value: 'bob',
        type: 'ganomede:email'
      })

      td.when(translatorsDeps.directoryClient.byId({id: 'alice'}, td.callback))
        .thenCallback(null, {aliases: {name: 'Alice of the Wonderland'}})

      td.when(translatorsDeps.directoryClient.byId({id: 'bob'}, td.callback))
        .thenCallback(null, {
          aliases: {
            name: 'Magnificent Bob',
            email: 'bob@magnificent-creatures.mail'
          }
        })

      translators.directory [t1, t2, t3, t4], (err, translations) ->
        expect(err).to.be(null)
        expect(translations).to.eql([
          new Translation(t1, 'Alice of the Wonderland')
          new Translation(t2, 'Alice of the Wonderland'),
          new Translation(t3, 'Magnificent Bob'),
          new Translation(t4, 'bob@magnificent-creatures.mail'),
        ])
        expect(td.explain(translatorsDeps.directoryClient.byId))
          .to.have.property('callCount', 2)
        done()

    it 'missing aliases are skipped', (done) ->
      t1 = new Translatable({
        field: 'something',
        index: 2,
        value: 'bob',
        type: 'ganomede:name'
      })

      t2 = new Translatable({
        field: 'something',
        index: 3,
        value: 'bob',
        type: 'ganomede:email'
      })

      td.when(translatorsDeps.directoryClient.byId({id: 'bob'}, td.callback))
        .thenCallback(null, {aliases: {}})

      translators.directory [t1, t2], (err, translations) ->
        expect(err).to.be(null)
        expect(translations).to.eql([])
        done()

    it 'does not fail on net errors (skips translations)', (done) ->
      t1 = new Translatable({
        field: 'something',
        index: 2,
        value: 'miss',
        type: 'ganomede:name'
      })

      td.when(translatorsDeps.directoryClient.byId({id: 'miss'}, td.callback))
        .thenCallback(
          new Error("Restify's 404"),
          {
            code: 'UserNotFoundError',
            message: 'User not found {"userId":"elmigrantoasdasd"}'
          }
        )

      translators.directory [t1], (err, translations) ->
        expect(err).to.be(null)
        expect(translations).to.eql([])
        done()

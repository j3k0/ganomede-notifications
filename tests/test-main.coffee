expect = require 'expect.js'
config = require '../config'

describe 'Main', () ->
  describe 'config.removeServiceVersion()', () ->
    test = (name, unversionedName) ->
      actual = config.removeServiceVersion(name)
      expected = if arguments.length == 1 then name else unversionedName
      expect(actual).to.be(expected)

    it 'returns name without a version from versioned service name', () ->
      test('service/v1', 'service')
      test('service/something/v1', 'service/something')

    it 'returns original string if no version is present', () ->
      test('service')
      test('service/v')
      test('service/v-2')
      test('service/vABC')
      test('service/not-a-version/more?')

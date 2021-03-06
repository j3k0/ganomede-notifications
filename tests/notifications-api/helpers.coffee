expect = require 'expect.js'

clone = (obj) -> JSON.parse(JSON.stringify(obj))

module.exports =
  expectToEqlExceptIdSecretTimestamp: (left, right) ->
    left = clone(left)
    right = clone(right)

    ['id', 'secret', 'timestamp'].forEach (key) ->
      delete left[key]
      delete right[key]

    expect(left).to.eql(right)

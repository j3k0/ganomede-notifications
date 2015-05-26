delay = (ms, fn) -> setTimeout(fn, ms)

clone = (obj) -> JSON.parse(JSON.stringify(obj))

reverseArray = (arr) ->
  copy = clone(arr)
  reversed = []

  for item in copy
    reversed.unshift(item)

  return reversed

module.exports =
  delay: delay
  clone: clone
  reverseArray: reverseArray

  TEST_LIST: ['alice', 'bob', 'jdoe']

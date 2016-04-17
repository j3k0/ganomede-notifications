Token = require './token'

# Within redis hash we have
#  #{type:device}: value
toHashSubkey = (token) -> "#{token.type}:#{token.device}"
fromHashSubkey = (subkey, value) ->
  parts = subkey.split(':')
  return {
    type: parts[0],
    device: parts[1],
    value
  }

class TokenStorage
  constructor: (redis) ->
    @redis = redis

  # Adds token to redis.
  # callback(err, added)
  add: (token, callback) ->
    @redis.hset token.key, toHashSubkey(token), token.value, (err, reply) ->
      # 1 for adding
      # 0 for updating
      callback(err, reply == 1)

  # Retrieves username's tokens for particular app
  get: (username, app, callback) ->
    key = Token.key(username, app)

    @redis.hgetall key, (err, tokens) ->
      if (err)
        return callback(err)

      ret = []
      if tokens
        ret = Object.keys(tokens).map (subkey) ->
          return new Token(key, fromHashSubkey(subkey, tokens[subkey]))

      callback(null, ret)

  _upgrade: (from, to, callback) ->
    r = @redis
    self = @
    if !from then from = 0
    if !to then to = 4
    prefix = Token.key('', '').slice(0, -2)
    mask = "#{prefix}:*"
    upgradedTokens = {}

    console.log('working with', {from, to, prefix, mask})

    require('vasync').waterfall([
      (cb) -> r.select(from, cb)
      (reply, cb) -> r.keys(mask, cb)
      (keys, cb) ->
        multi = r.multi()
        keys.forEach (key) ->
          multi.smembers(key)
          multi.move(key, to)

        console.log("moving #{keys.length}…")

        multi.exec (err, replies) ->
          if (err) then return cb(err)
          smembers = replies
            .filter (r, idx) -> 0 == idx % 2 # replies to smembers command
            .map (set, idx) -> {key: keys[idx], set}
          cb(null, smembers)

      (smembers, cb) ->
        multi = r.multi()
        tokensToCreate = []

        smembers.forEach ({key, set}) ->
          findFirst = (type) ->
            ret = null
            set.some (item) ->
              if (item.indexOf(type) == 0)
                ret = item
                return true
            return ret

          apn = findFirst(Token.APN)
          gcm = findFirst(Token.GCM)

          if (apn)
            tokensToCreate.push(new Token(key, {
              type: Token.APN,
              value: apn.slice(Token.APN.length + 1)
            }))

          if (gcm)
            tokensToCreate.push(new Token(key, {
              type: Token.GCM
              value: gcm.slice(Token.GCM.length + 1)
            }))

        if tokensToCreate.length == 0
          console.log("db #{from} has no tokens with prefix #{prefix}")
          return

        console.log("upgrading #{tokensToCreate.length} tokens…")

        tokensToCreate.forEach (token) ->
          multi.hset token.key, toHashSubkey(token), token.value

        multi.exec(cb)
    ], callback)

module.exports = TokenStorage

unless module.parent
  config = require('../../config')
  redis = require('redis').createClient(
    config.pushApi.redisPort,
    config.pushApi.redisHost
  )

  from = process.env.DB_FROM
  to = process.env.DB_TO

  process.on('beforeExit', redis.quit.bind(redis))

  new TokenStorage(redis)._upgrade from, to, (err, results) ->
    if (err)
      console.error('failed', err)
      return process.exit(1)

    console.log(require('util').inspect(results, {depth: 12}))
    console.log('Done!')
    process.exit(0)

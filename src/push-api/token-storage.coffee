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

  # Scan redis db @from for push tokens in old format,
  # upgrade them to new format.
  _upgrade: (from, callback) ->
    vasync = require('vasync')
    r = @redis
    if !from then from = 0
    newPrefix = Token.key('', '').slice(0, -2)
    oldPrefix = 'notifications:push-tokens'
    mask = "#{oldPrefix}:*"
    upgradedTokens = {}

    console.log('working with', {db: from, newPrefix, oldPrefix, mask})

    vasync.waterfall([
      # switch redis db
      (cb) -> r.select(from, cb)
      # get keys of old sets
      (reply, cb) ->
        console.log('looking for keys to upgrade…')
        r.keys mask, (err, keys) ->
          if (err) then return cb(err)
          oldKeys = keys.filter (key) -> -1 == key.indexOf(newPrefix)
          cb(null, oldKeys)
      # convert old values to new format
      (keys, cb) ->
        console.log("converting #{keys.length} keys…")
        tokensToCreate = []

        findFirst = (type, set) ->
          ret = null
          set.some (item) ->
            if (item.indexOf(type) == 0)
              ret = item
              return true
          return ret

        upgradeKey = (key, cb) ->
          r.smembers key, (err, tokens) ->
            if (err) then return cb(err)
            apn = findFirst(Token.APN, tokens)
            gcm = findFirst(Token.GCM, tokens)
            newKey = key.replace(oldPrefix, newPrefix)

            if (apn)
              tokensToCreate.push(new Token(newKey, {
                type: Token.APN,
                value: apn.slice(Token.APN.length + 1)
              }))

            if (gcm)
              tokensToCreate.push(new Token(newKey, {
                type: Token.GCM
                value: gcm.slice(Token.GCM.length + 1)
              }))

            cb()

        vasync.forEachParallel({
          inputs: keys,
          func: upgradeKey
        }, (err) -> cb(err, tokensToCreate))
      # save converted tokens into redis
      (tokensToCreate, cb) ->
        if tokensToCreate.length == 0
          console.log("db #{from} has no tokens with prefix #{prefix}")
          return cb()

        console.log("saving #{tokensToCreate.length} upgraded tokens…")

        multi = r.multi()

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

  process.on('beforeExit', redis.quit.bind(redis))

  new TokenStorage(redis)._upgrade from, (err, results) ->
    if (err)
      console.error('failed', err)
      return process.exit(1)

    nUpdated = results.filter((reply) -> reply == 0).length
    nCreated = results.filter((reply) -> reply == 1).length

    console.log "Done! Upgraded #{results.length} tokens:", {nUpdated, nCreated}
    process.exit(0)

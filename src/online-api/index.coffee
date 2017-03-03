redis = require 'redis'
authdb = require "authdb"
ganomedeHelpers = require 'ganomede-helpers'
ListManager = require './list-manager'
config = require '../../config'
log = require('../log').child(module: "online-api")
restify = require "restify"

createApi = (options={}) ->
  onlineList = options.onlineList || new ListManager(
    redis.createClient(
      config.onlineList.redisPort,
      config.onlineList.redisHost,
      {no_ready_check: true}
    ),

    {
      maxSize: config.onlineList.maxSize,
      invisibleUsernameRegExp: config.onlineList.invisibleUsernameRegExp
    }
  )

  # Populates req.params.user with value returned from authDb.getAccount()
  authMiddleware = ganomedeHelpers.restify.middlewares.authdb.create({
    authdbClient: options.authdbClient || authdb.createClient(
      host: config.authdb.host
      port: config.authdb.port
    ),
    secret: config.secret
  })

  # Return list of usernames most recently online.
  fetchList = (req, res, next) ->
    listId = req.params?.listId
    onlineList.get req.params.listId, (err, list) ->
      if (err)
        log.error('fetchList() failed', {listId, err})
        return next(new restify.InternalServerError())

      res.json(list)
      next()

  # Adds user to the list and returns updated list.
  updateList = (req, res, next) ->
    listId = req.params?.listId
    profile = req.params?.user

    onlineList.add listId, profile, (err, newList) ->
      if (err)
        log.error('updateList() failed', {listId, err})
        return next(new restify.InternalServerError())

      res.json(newList)
      next()

  return (prefix, server) ->
    # Fetch lists
    server.get("/#{prefix}/online", fetchList)
    server.get("/#{prefix}/online/:listId", fetchList)

    # Update lists
    updateStack = [authMiddleware, updateList]
    server.post("/#{prefix}/auth/:authToken/online", updateStack)
    server.post("/#{prefix}/auth/:authToken/online/:listId", updateStack)

module.exports = createApi

# vim: ts=2:sw=2:et:

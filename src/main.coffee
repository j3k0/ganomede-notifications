log = require "./log"
aboutApi = require "./about-api"
pingApi = require "./ping-api"
notificationsApi = require "./notifications-api"
onlineApiLib = require './online-api'

addRoutes = (prefix, server) ->
  log.info "adding routes to #{prefix}"

  # Platform Availability
  pingApi.addRoutes prefix, server

  # About
  aboutApi.addRoutes prefix, server
  
  # Online list
  onlineApi = onlineApiLib()
  onlineApi(prefix, server)

  # Notifications
  api = notificationsApi(
    updateOnlineListMiddleware: onlineApi.updateOnlineListMiddleware
  )
  api(prefix, server)

initialize = (callback) ->
  log.info "initializing backend"
  callback?()

destroy = ->
  log.info "destroying backend"

module.exports =
  initialize: initialize
  destroy: destroy
  addRoutes: addRoutes
  log: log

# vim: ts=2:sw=2:et:

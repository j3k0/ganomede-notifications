log = require "./log"
aboutApi = require "./about-api"
pingApi = require "./ping-api"
notificationsApi = require "./notifications-api"
createOnlineApi = require './online-api'
pushApiLib = require './push-api'

addRoutes = (prefix, server) ->
  log.info "adding routes to #{prefix}"

  # Platform Availability
  pingApi.addRoutes prefix, server

  # About
  aboutApi.addRoutes prefix, server

  # Online list
  onlineApi = createOnlineApi()
  onlineApi(prefix, server)

  # Push API
  pushApi = pushApiLib()
  pushApi(prefix, server)

  # Notifications
  api = notificationsApi(
    addPushNotification: pushApi.addPushNotification
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

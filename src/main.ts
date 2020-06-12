/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import log from "./log";
import aboutApi from "./about-api";
import pingApi from "./ping-api";
import notificationsApi from "./notifications-api";
import createOnlineApi from './online-api';
import pushApiLib from './push-api';

const addRoutes = function(prefix, server) {
  log.info(`adding routes to ${prefix}`);

  // Platform Availability
  pingApi.addRoutes(prefix, server);

  // About
  aboutApi.addRoutes(prefix, server);

  // Online list
  const onlineApi = createOnlineApi();
  onlineApi(prefix, server);

  // Push API
  const pushApi = pushApiLib();
  pushApi(prefix, server);

  // Notifications
  const api = notificationsApi({
    addPushNotification: pushApi.addPushNotification,
    onUserRequest: onlineApi.onUserRequest,
  });
  return api(prefix, server);
};

const initialize = function(callback?:()=>void) {
  log.info("initializing backend");
  return (typeof callback === 'function' ? callback() : undefined);
};

const destroy = () => log.info("destroying backend");

export default {
  initialize,
  destroy,
  addRoutes,
  log
};

// vim: ts=2:sw=2:et:

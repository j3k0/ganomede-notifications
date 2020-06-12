/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import bunyan from "bunyan";

export const log = bunyan.createLogger({name: "notifications"});
export type Logger = typeof log;
export default log;
// vim: ts=2:sw=2:et:

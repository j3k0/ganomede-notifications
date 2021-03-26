import bunyan from "bunyan";
export const log = bunyan.createLogger({
    name: "notifications",
    level: (process.env.LOG_LEVEL as bunyan.LoggerOptions["level"]) || 'info'
});
export type Logger = typeof log;
export default log;
// vim: ts=2:sw=2:et:

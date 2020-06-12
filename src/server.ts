import * as restify from 'restify';
import logger from './log';
import config from '../config';
import sendAuditStats from './send-audit-stats';

const matchSecret = (obj, prop) => {
  const has = obj && obj[prop] && Object.hasOwnProperty.call(obj[prop], 'secret');
  const match = has && (typeof obj[prop].secret === 'string')
    && (obj[prop].secret.length > 0) && (obj[prop].secret === config.secret);

  if (has)
    delete obj[prop].secret;

  return match;
};

const shouldLogRequest = (req) =>
  req.url.indexOf(`${config.http.prefix}/ping/_health_check`) !== 0;

const shouldLogResponse = (res) =>
  (res && res.statusCode >= 500);

const filteredLogger = (errorsOnly, logger) => (req, res, next) => {
  const logError = errorsOnly && shouldLogResponse(res);
  const logInfo = !errorsOnly && (
    shouldLogRequest(req) || shouldLogResponse(res));
  if (logError || logInfo)
    logger(req, res);
  if (next && typeof next === 'function')
    next();
};

export default {
  createServer: () => {

    logger.info({env: process.env}, 'environment');

    const server = restify.createServer({
      handleUncaughtExceptions: true,
      log: logger
    });

    const requestLogger = filteredLogger(false, (req) =>
      req.log.info({req_id: req.id()}, `${req.method} ${req.url}`));
    server.use(requestLogger);

    server.use(restify.plugins.queryParser());
    server.use(restify.plugins.bodyParser());

    // Audit requests
    server.on('after', filteredLogger(process.env.NODE_ENV === 'production',
      restify.plugins.auditLogger({event: 'after', log: logger, body: true})));

    // Automatically add a request-id to the response
    function setRequestId(req, res, next) {
      req.log = req.log.child({req_id: req.id()});
      res.setHeader('X-Request-Id', req.id());
      return next();
    }
    server.use(setRequestId);

    // Send audit statistics
    server.on('after', sendAuditStats);

    // Init object to dump our stuff into.
    server.use(function secretMatcher(req: restify.Request, res: restify.Response, next: restify.Next) {
      req.ganomede = {
        secretMatches: matchSecret(req, 'body') || matchSecret(req, 'query')
      };

      next();
    });

    return server;
  }
};

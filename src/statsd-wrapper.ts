import logMod from './log';
import StatsD from 'node-statsd';

const dummyClient = () => ({
  increment() {},
  timing() {},
  decrement() {},
  histogram() {},
  gauge() {},
  set() {},
  unique() {}
});

const requiredEnv = [ 'STATSD_HOST', 'STATSD_PORT', 'STATSD_PREFIX' ];

const missingEnv = function() {
  for (let e of Array.from(requiredEnv)) {
    if (!process.env[e]) {
      return e;
    }
  }
  return undefined;
};

const createClient = function(...args) {
  const val = args[0], obj = val != null ? val : {}, val1 = obj.log, log = val1 != null ? val1 : logMod.child({module: "statsd"});
  if (missingEnv()) {
    log.warn("Can't initialize statsd, missing env: " + missingEnv());
    return dummyClient();
  }
  const client = new StatsD({
    host: process.env.STATSD_HOST,
    port: process.env.STATSD_PORT,
    prefix: process.env.STATSD_PREFIX || 'ganomede.notifications.'
  });
  client.socket.on('error', error => log.error("error in socket", error));
  return client;
};

export default {
  createClient,
  dummyClient
};

class LP {

  trigger: () => void;
  timeout: () => void;
  timeoutId: NodeJS.Timeout|null;

  constructor(onTrigger, onTimeout) {
    this.trigger = onTrigger;
    this.timeout = onTimeout;
    this.timeoutId = null;
  }

  start(millis) {
    this.stop();
    return this.timeoutId = setTimeout(this.timeout.bind(this), millis);
  }

  stop() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
    }

    return this.timeoutId = null;
  }
}

class LongPoll {
  millis: number;
  store: object;

  constructor(timeoutMillis:number) {
    this.millis = timeoutMillis;
    this.store = {};
  }

  clear(key:string):void {
    if (this.store.hasOwnProperty(key)) {
      const lp = this.store[key];
      delete this.store[key];
      lp.stop();
    }
  }

  clearBefore(key:string, cb:()=>void) {
    const clear = this.clear.bind(this, key);
    return function() {
      clear();
      cb();
    };
  }

  add(key:string, onTrigger:(key:string)=>void, onTimeout:(key:string)=>void) {
    if (this.store.hasOwnProperty(key)) {
      // Getting here means the same user listens twice to its stream of events...
      // He might be connected with the same username on two devices.
      // Let the first "listened" timeout...
      // (this legacy code was trying to be smarter than that, but actually results
      // in some 504 errors when more than half the time already passed)
      // this.store[key].stop();
      // setTimeout(this.store[key].timeout.bind(this.store[key]), this.millis / 2);
    }

    const triggerFn = this.clearBefore(key, onTrigger.bind(null, key));
    const timeoutFn = this.clearBefore(key, onTimeout.bind(null, key));
    const lp = new LP(triggerFn, timeoutFn);

    this.store[key] = lp;
    lp.start(this.millis);
  }

  trigger(key:string):void {
    if (this.store.hasOwnProperty(key)) {
      this.store[key].trigger();
      delete this.store[key];
    }
  }
}

export default LongPoll;

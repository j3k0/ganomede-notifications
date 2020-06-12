import { AuthUser } from '../src/types';

class AuthdbClient {
  store: {[token: string]: AuthUser};
  constructor() {
    this.store = {};
  }
  removeAccount(token: string, cb: () => void) {}
  addAccount(token: string, user: object) {
    return this.store[token] = user;
  }
  getAccount(token: string, cb: (err: Error|string|null, user: object|null) => void) {
    if (!this.store[token]) {
      return cb("invalid authentication token", null);
    }
    return cb(null, this.store[token] || null);
  }
}

export default {createClient() { return new AuthdbClient; }};

// vim: ts=2:sw=2:et:

'use strict';

// Some deps use `process.EventEmitter` (restify@2 > spdy) which is deprecated.
// Let's temporarily fix this like this, and maybe upgrade to restify@4 later.
try {
  process.EventEmitter = require('events').EventEmitter;
}
catch (e) {
  // ignore when process.EventEmitter is read-only
}

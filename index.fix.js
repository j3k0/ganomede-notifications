'use strict';

// Some deps use `process.EventEmitter` (restify@2 > spdy) which is deprecated.
// Let's temporarily fix this like this, and maybe upgrade to restify@4 later.
process.EventEmitter = require('events').EventEmitter;

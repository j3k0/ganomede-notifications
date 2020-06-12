/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import expect from 'expect.js';

const clone = obj => JSON.parse(JSON.stringify(obj));

export default {
  expectToEqlExceptIdSecretTimestamp(left, right) {
    left = clone(left);
    right = clone(right);

    ['id', 'secret', 'timestamp'].forEach(function(key) {
      delete left[key];
      return delete right[key];});

    return expect(left).to.eql(right);
  }
};

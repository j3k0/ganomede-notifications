/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import expect from 'expect.js';
import config from '../config';
import {describe, it} from 'mocha';

describe('Main', () => describe('config.removeServiceVersion()', function() {
  const test = function(name:string, unversionedName?:string) {
    const actual = config.removeServiceVersion(name);
    const expected = arguments.length === 1 ? name : unversionedName;
    expect(actual).to.be(expected);
  };

  it('returns name without a version from versioned service name', function() {
    test('service/v1', 'service');
    test('service/something/v1', 'service/something');
  });

  it('returns original string if no version is present', function() {
    test('service');
    test('service/v');
    test('service/v-2');
    test('service/vABC');
    test('service/not-a-version/more?');
  });
}));

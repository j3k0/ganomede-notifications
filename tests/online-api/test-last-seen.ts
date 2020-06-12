import * as vasync from 'vasync';
import expect from 'expect.js';
import * as fakeRedis from 'fakeredis';
import {describe, it} from 'mocha';
import {createClient} from '../../src/online-api/last-seen';

describe('online-api/last-seen', function() {
    it('store a date for users', function(done) {
        const redis = fakeRedis.createClient();
        const lastSeen = createClient({ redis });
        const date = '2020-10-18T14:30:00.000Z'
        vasync.waterfall([
            (cb) => { lastSeen.save('thea', new Date(date), cb) },
            (_ok, cb) => { redis.keys('*', cb) },
            (keys, cb) => {
                expect(keys.length).to.equal(1);
                cb();
            },
            (cb) => { lastSeen.load(['thea'], cb) },
            (values, cb) => {
                expect(values?.thea?.toISOString()).to.equal(date);
                cb();
            }
        ], (err) => {
            expect(err).to.be(null);
            done();
        });
    });
});
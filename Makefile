BUNYAN_LEVEL?=1000

MOCHA_FLAGS=--bail \
	--recursive \
	--require index.fix.js \
	--compilers coffee:coffee-script/register

all: install test

check: install
	shellcheck -s bash push-worker.sh
	./node_modules/.bin/eslint --config ./.eslintrc index.js index.fix.js config.js newrelic.js
	./node_modules/.bin/coffeelint -q src tests
	grep -R -n -A5 -i TODO src tests

test: check
	API_SECRET=1 ./node_modules/.bin/mocha ${MOCHA_FLAGS}  tests | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL}

testw:
	API_SECRET=1 ./node_modules/.bin/mocha --watch ${MOCHA_FLAGS}  tests | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL}

coverage: test
	@mkdir -p doc
	API_SECRET=1 ./node_modules/.bin/mocha ${MOCHA_FLAGS} --require blanket -R html-cov tests | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL} > doc/coverage.html
	@echo "coverage exported to doc/coverage.html"

run: check
	node index.js | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL}

run-worker: check
	./node_modules/.bin/coffee src/push-api/sender-cli.coffee | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL}

run-worker-loop: check
	./push-worker.sh | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL}

install: node_modules

node_modules: package.json
	npm install
	@touch node_modules

clean:
	rm -fr node_modules

docker-prepare:
	@mkdir -p doc
	docker-compose up -d --no-recreate redisAuth redisNotifications

docker-run: docker-prepare
	docker-compose run --rm --service-ports app make run BUNYAN_LEVEL=${BUNYAN_LEVEL}

docker-run-worker: docker-prepare
	docker-compose run --rm --service-ports app make run-worker "BUNYAN_LEVEL=${BUNYAN_LEVEL}" "TEST_APN_TOKEN=${TEST_APN_TOKEN}" "APN_KEY_FILEPATH=${APN_KEY_FILEPATH}" "APN_CERT_FILEPATH=${APN_CERT_FILEPATH}"

docker-run-worker-loop: docker-prepare
	docker-compose run --rm --service-ports app make run-worker-loop "BUNYAN_LEVEL=${BUNYAN_LEVEL}" "TEST_APN_TOKEN=${TEST_APN_TOKEN}" "APN_KEY_FILEPATH=${APN_KEY_FILEPATH}" "APN_CERT_FILEPATH=${APN_CERT_FILEPATH}"

docker-test: docker-prepare
	docker-compose run --rm app make test BUNYAN_LEVEL=${BUNYAN_LEVEL}

docker-coverage: docker-prepare
	docker-compose run --rm app make coverage


BUNYAN_LEVEL?=1000

MOCHA_FLAGS=--bail --recursive --color --require ts-node/register --extensions ts

all: install test

check: install
	shellcheck -s bash push-worker.sh
	tsc
	grep -R -n -A5 -i TODO src tests

test: check
	API_SECRET=1 npx mocha ${MOCHA_FLAGS} tests/**/test-*.ts | npx bunyan -l ${BUNYAN_LEVEL}

testw:
	API_SECRET=1 npx mocha --watch ${MOCHA_FLAGS} tests/**/test-*.ts | npx bunyan -l ${BUNYAN_LEVEL}

coverage: test
	@mkdir -p doc
	API_SECRET=1 ./node_modules/.bin/mocha ${MOCHA_FLAGS} --require blanket -R html-cov tests | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL} > doc/coverage.html
	@echo "coverage exported to doc/coverage.html"

run: check
	node build/index.js | npx bunyan -l ${BUNYAN_LEVEL}

run-worker: check
	node build/src/push-api/sender-cli | npx bunyan -l ${BUNYAN_LEVEL}

run-worker-loop: check
	./push-worker.sh | npx bunyan -l ${BUNYAN_LEVEL}

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


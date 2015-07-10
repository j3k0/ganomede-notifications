BUNYAN_LEVEL?=1000

all: install test

check: install
	./node_modules/.bin/eslint src/
	./node_modules/.bin/coffeelint -q src tests

test: check
	./node_modules/.bin/mocha -b --recursive --compilers coffee:coffee-script/register tests | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL}

coverage: test
	@mkdir -p doc
	./node_modules/.bin/mocha -b --recursive --compilers coffee:coffee-script/register --require blanket -R html-cov tests | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL} > doc/coverage.html
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
	docker-compose run --rm --service-ports app make run-worker "BUNYAN_LEVEL=${BUNYAN_LEVEL}" "TEST_APN_TOKEN=${TEST_APN_TOKEN}"

docker-run-worker-loop: docker-prepare
	docker-compose run --rm --service-ports app make run-worker-loop "BUNYAN_LEVEL=${BUNYAN_LEVEL}" "TEST_APN_TOKEN=${TEST_APN_TOKEN}"

docker-test: docker-prepare
	docker-compose run --rm app make test BUNYAN_LEVEL=${BUNYAN_LEVEL}

docker-coverage: docker-prepare
	docker-compose run --rm app make coverage


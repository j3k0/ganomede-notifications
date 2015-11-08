#!/bin/bash
cd "`dirname $0`/../.."
set -e

if [ _ = _$TEST_GCM_TOKEN ]; then
    echo "Please set ENV: TEST_GCM_TOKEN"
    exit 1
fi

if [ _ = _$TEST_GCM_API_KEY ]; then
    echo "Please set ENV: TEST_GCM_API_KEY"
    exit 1
fi

if [ _$1 != _nobuild ]; then
    docker-compose build app
fi

docker run -it --rm -v $(pwd)/src:/home/app/code/src -v $(pwd)/tests:/home/app/code/tests -e "TEST_GCM_API_KEY=$TEST_GCM_API_KEY" -e "TEST_GCM_TOKEN=$TEST_GCM_TOKEN" notifications_app /home/app/code/node_modules/.bin/mocha --compilers coffee:coffee-script/register tests/push-api/test-sender.coffee

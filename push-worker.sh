#!/bin/bash

set -e
cd "$(dirname "$0")"

TEMPDIR="$(mktemp -d)"

if [[ ! -z "$APN_KEY_BASE64" ]]; then
    echo "$APN_KEY_BASE64" | base64 -d > "$TEMPDIR/key.pem"
    echo "Extracted key to $TEMPDIR/key.pem"
    export APN_KEY_FILEPATH="$TEMPDIR/key.pem"
fi

if [[ ! -z "$APN_CERT_BASE64" ]]; then
    echo "$APN_CERT_BASE64" | base64 -d > "$TEMPDIR/cert.pem"
    echo "Extracted cert to $TEMPDIR/cert.pem"
    export APN_CERT_FILEPATH="$TEMPDIR/cert.pem"
fi

if [[ -z "$WORKER_INTERVAL" ]]; then
    WORKER_INTERVAL=1
fi

function monitor() {
    while sleep 10; do
        QUEUE_SIZE="$(redis-cl -h "$REDIS_PUSHAPI_PORT_6379_TCP_ADDR" -p "$REDIS_PUSHAPI_PORT_6379_TCP_PORT" --raw LLEN notifications:push-notifications)"
        # NOTE STATSD_PREFIX ends with a "." (dot character)
        echo "${STATSD_PREFIX}message_queue_length:$QUEUE_SIZE|g" | nc -w 1 -u "$STATSD_HOST" "$STATSD_PORT"
        if [ "$QUEUE_SIZE" -gt "1000" ]; then
            kill "$PUSH_WORKER_PID"
        fi
    done
}

monitor &

# Launch 1 worker per second.
#
# If worker can't finish its job under N seconds, 2 workers will run in parallel.
# This is cheap autoscaling.
while true; do
    date -u +"[%Y-%m-%dT%H:%M:%SZ]"
    # echo ./node_modules/.bin/coffee src/push-api/sender-cli.coffee
    ./node_modules/.bin/coffee src/push-api/sender-cli.coffee &
    PUSH_WORKER_PID=$!
    wait
    sleep $WORKER_INTERVAL
done

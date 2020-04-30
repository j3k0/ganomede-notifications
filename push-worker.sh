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

PUSH_WORKER_PID=
function run_worker() {
    ./node_modules/.bin/coffee src/push-api/sender-cli.coffee &
    PUSH_WORKER_PID="$!"
    wait "$PUSH_WORKER_PID"
    PUSH_WORKER_PID=""
}
function stop_worker() {
    local KILL_WORKER_PID
    if [ ! -z "$PUSH_WORKER_PID" ]; then
        KILL_WORKER_PID="$PUSH_WORKER_PID"
        PUSH_WORKER_PID=""
        kill "$KILL_WORKER_PID" || true
        sleep 10
        # still not restarted? kill harder
        if [ -z "$PUSH_WORKER_PID" ]; then
            kill -9 "$KILL_WORKER_PID" || true
        fi
    fi
}

function monitor() {
    local LAST_QUEUE_SIZE
    local QUEUE_SIZE
    LAST_QUEUE_SIZE="$(redis-cli -h "$REDIS_PUSHAPI_PORT_6379_TCP_ADDR" -p "$REDIS_PUSHAPI_PORT_6379_TCP_PORT" --raw LLEN notifications:push-notifications || true)"
    while sleep 10; do
        QUEUE_SIZE="$(redis-cli -h "$REDIS_PUSHAPI_PORT_6379_TCP_ADDR" -p "$REDIS_PUSHAPI_PORT_6379_TCP_PORT" --raw LLEN notifications:push-notifications || true)"
        # NOTE: STATSD_PREFIX ends with a "." (dot character)
        echo "${STATSD_PREFIX}message_queue_length:$QUEUE_SIZE|g" | nc -w 1 -u "$STATSD_HOST" "$STATSD_PORT" || true
        if [ ! -z "$QUEUE_SIZE" ]; then
            if [ "$QUEUE_SIZE" -gt "100" ] && [ "$QUEUE_SIZE" -gt "$LAST_QUEUE_SIZE" ]; then
                stop_worker &
            fi
            LAST_QUEUE_SIZE="$QUEUE_SIZE"
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
    run_worker
    sleep "$WORKER_INTERVAL"
done

#!/bin/bash

set -e
cd "`dirname $0`"

TEMPDIR="`mktemp -d`"

if [[ ! -z "$APN_KEY_BASE64" ]]; then
    echo "$APN_KEY_BASE64" | base64 -d > "$TEMPDIR/key.pem"
    echo "Extracted key to $TEMPDIR/key.pem"
    export APN_KEY_FILEPATH="$TEMPDIR/key.pem"
fi

if [[ ! -z "$APN_CERT_BASE64" ]]; then
    echo "$APN_CERT_BASE64" | base64 -d > "$TEMPDIR/cert.pem"
    echo "Extracted cert to $TEMPDIR/key.pem"
    export APN_CERT_FILEPATH="$TEMPDIR/cert.pem"
fi

if [[ -z "$WORKER_INTERVAL" ]]; then
    WORKER_INTERVAL=1
fi

# Launch 1 worker per second.
#
# If worker can't finish its job under N seconds, 2 workers will run in parallel.
# This is cheap autoscaling.
while true; do
    echo ./node_modules/.bin/coffee src/push-api/sender-cli.coffee
    ./node_modules/.bin/coffee src/push-api/sender-cli.coffee &
    sleep $WORKER_INTERVAL
done

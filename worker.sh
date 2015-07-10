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

./node_modules/.bin/coffee src/push-api/sender-cli.coffee

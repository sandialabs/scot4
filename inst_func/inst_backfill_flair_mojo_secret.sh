#!/bin/bash
set -euo pipefail

KCTL="${KCTL:-/usr/local/bin/kubectl}"
NAMESPACE="${1:-scot4}"
SECRET_NAME="scot4-flair-secrets"
SECRET_KEY="S4FLAIR_MOJO_SECRETS"
PATCH_FILE=""

cleanup() {
    if [ -n "$PATCH_FILE" ] && [ -f "$PATCH_FILE" ]; then
        rm -f -- "$PATCH_FILE"
    fi
}

trap cleanup EXIT

if ! "$KCTL" -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
    echo "!!! $SECRET_NAME does not exist; refusing to backfill $SECRET_KEY !!!" >&2
    exit 1
fi

encoded_value=$("$KCTL" -n "$NAMESPACE" get secret "$SECRET_NAME" \
    -o "jsonpath={.data.$SECRET_KEY}")
current_value=""
if [ -n "$encoded_value" ]; then
    current_value=$(printf '%s' "$encoded_value" | base64 --decode)
fi

case "$current_value" in
    ""|"UPDATE-ME"|"UPDATE_ME"|"CHANGE-ME"|"CHANGE_ME"|"CHANGEME"|"TODO"|\<*\>)
        ;;
    *)
        echo "$SECRET_NAME already contains a valid $SECRET_KEY"
        exit 0
        ;;
esac

generated_value=$(openssl rand -base64 48 | tr -d '\n')
encoded_value=$(printf '%s' "$generated_value" | base64 | tr -d '\n')

umask 077
PATCH_FILE=$(mktemp /tmp/scot4-flair-mojo-secret.XXXXXXXX.json)
printf '{"data":{"%s":"%s"}}\n' "$SECRET_KEY" "$encoded_value" >"$PATCH_FILE"

"$KCTL" -n "$NAMESPACE" patch secret "$SECRET_NAME" \
    --type=merge --patch-file "$PATCH_FILE" >/dev/null

echo "added $SECRET_KEY to $SECRET_NAME"

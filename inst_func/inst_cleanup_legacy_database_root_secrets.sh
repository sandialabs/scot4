#!/bin/bash
set -euo pipefail

KCTL="${KCTL:-/usr/local/bin/kubectl}"
NAMESPACE="${1:-scot4}"

verify_database_root_secret() {
    local deployment="$1"
    local container="$2"
    local legacy_secret="$3"

    if ! "$KCTL" -n "$NAMESPACE" get deployment "$deployment" >/dev/null 2>&1; then
        return 0
    fi

    local deployed_container
    deployed_container="$($KCTL -n "$NAMESPACE" get deployment "$deployment" \
        -o 'jsonpath={.spec.template.spec.containers[0].name}')"
    if [ "$deployed_container" != "$container" ]; then
        echo "!!! expected container $container was not found in $deployment; refusing cleanup !!!"
        exit 1
    fi

    local root_secret
    root_secret="$($KCTL -n "$NAMESPACE" get deployment "$deployment" \
        -o 'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.name}')"
    if [ -z "$root_secret" ] || [ "$root_secret" = "$legacy_secret" ]; then
        echo "!!! $deployment is not using an isolated database root Secret; refusing cleanup !!!"
        exit 1
    fi
    if ! "$KCTL" -n "$NAMESPACE" get secret "$root_secret" >/dev/null 2>&1; then
        echo "!!! database root Secret $root_secret does not exist; refusing cleanup !!!"
        exit 1
    fi
}

verify_secret_key() {
    local secret="$1"
    local key="$2"

    if ! "$KCTL" -n "$NAMESPACE" get secret "$secret" >/dev/null 2>&1; then
        echo "!!! required Secret $secret does not exist; refusing cleanup !!!"
        exit 1
    fi
    if [ -z "$("$KCTL" -n "$NAMESPACE" get secret "$secret" -o "jsonpath={.data.$key}")" ]; then
        echo "!!! required key $secret/$key does not exist; refusing cleanup !!!"
        exit 1
    fi
}

remove_legacy_secret_key() {
    local secret="$1"
    local key="$2"

    if ! "$KCTL" -n "$NAMESPACE" get secret "$secret" >/dev/null 2>&1; then
        return 0
    fi
    if [ -n "$("$KCTL" -n "$NAMESPACE" get secret "$secret" -o "jsonpath={.data.$key}")" ]; then
        "$KCTL" -n "$NAMESPACE" patch secret "$secret" --type=json \
            -p="[{\"op\":\"remove\",\"path\":\"/data/$key\"}]"
        echo "removed legacy $key from $secret"
    fi
}

verify_database_root_secret scot4-db scot4-db scot4-env-secrets
verify_database_root_secret scot4-flair-db scot4-flair-db scot4-flair-secrets
if "$KCTL" -n "$NAMESPACE" get secret scot4-env-secrets >/dev/null 2>&1 \
    && [ -n "$("$KCTL" -n "$NAMESPACE" get secret scot4-env-secrets -o 'jsonpath={.data.FLAIR_DB_PASSWORD}')" ]; then
    verify_secret_key scot4-flair-secrets FLAIR_DB_PASSWORD
fi
remove_legacy_secret_key scot4-env-secrets ROOT_DB_PASSWORD
remove_legacy_secret_key scot4-flair-secrets ROOT_DB_PASSWORD
remove_legacy_secret_key scot4-env-secrets FLAIR_DB_PASSWORD

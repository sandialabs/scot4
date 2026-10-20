#!/bin/bash
set -euo pipefail

KCTL="${KCTL:-/usr/local/bin/kubectl}"
NAMESPACE="${1:-scot4}"

if ! "$KCTL" -n "$NAMESPACE" get secret scot4-meilisearch-secrets >/dev/null 2>&1; then
    echo "!!! scot4-meilisearch-secrets does not exist; refusing to remove legacy keys !!!"
    exit 1
fi

MASTER_KEY_SECRET="$($KCTL -n "$NAMESPACE" get statefulset scot4-search \
    -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].secretRef.name}')"
if [[ " $MASTER_KEY_SECRET " != *" scot4-meilisearch-secrets "* ]]; then
    echo "!!! scot4-search is not using scot4-meilisearch-secrets; refusing to remove legacy keys !!!"
    exit 1
fi

API_INIT_CONTAINERS="$($KCTL -n "$NAMESPACE" get deployment scot4-api \
    -o jsonpath='{.spec.template.spec.initContainers[*].name}')"
if [[ " $API_INIT_CONTAINERS " != *" scot4-provision-search-api-key "* ]]; then
    echo "!!! scot4-api does not contain the search-key initializer; refusing to remove legacy keys !!!"
    exit 1
fi

for KEY in MEILI_MASTER_KEY SEARCH_API_KEY; do
    if [ -n "$($KCTL -n "$NAMESPACE" get secret scot4-env-secrets -o "jsonpath={.data.$KEY}")" ]; then
        "$KCTL" -n "$NAMESPACE" patch secret scot4-env-secrets --type=json \
            -p="[{\"op\":\"remove\",\"path\":\"/data/$KEY\"}]"
        echo "removed legacy $KEY from scot4-env-secrets"
    fi
done

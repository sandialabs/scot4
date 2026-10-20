#!/bin/bash
set -euxo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM=/usr/local/bin/helm
export KUBECONFIG="/home/scot4/.kube/config"

"$SCRIPT_DIR/inst_backfill_flair_mojo_secret.sh"

$HELM upgrade -n scot4 \
    --install \
    --reset-values \
    -f OS_values.yaml \
    --set scot4.cleanFlairInstall=true \
    --set scot4.wipeApiDatabase=true \
    scot4 ./scot4

"$SCRIPT_DIR/inst_cleanup_legacy_meilisearch_secrets.sh"
"$SCRIPT_DIR/inst_cleanup_legacy_database_root_secrets.sh"

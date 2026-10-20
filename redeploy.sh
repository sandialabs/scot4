#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/check_chart_dependencies.sh" "$SCRIPT_DIR/scot4"
"$SCRIPT_DIR/inst_func/inst_backfill_flair_mojo_secret.sh"
/usr/local/bin/helm upgrade \
    -n scot4 \
    --install \
    --reset-values \
    -f OS_values.yaml \
    --set scot4.cleanFlairInstall=false \
    --set scot4.wipeApiDatabase=false \
    scot4 ./scot4

"$SCRIPT_DIR/inst_func/inst_cleanup_legacy_meilisearch_secrets.sh"
"$SCRIPT_DIR/inst_func/inst_cleanup_legacy_database_root_secrets.sh"

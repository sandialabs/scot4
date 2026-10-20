#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
"$BASE_DIR/check_chart_dependencies.sh" "$BASE_DIR/scot4"

BASE="/usr/local/bin/helm upgrade -n scot4"
OPTS="--install --reset-values"
INCL="-f OS_values.yaml"
DANGER='--set scot4.cleanFlairInstall=true --set scot4.wipeApiDatabase=true'
SUFFIX="scot4 ./scot4"

PARAMS="$INCL $DANGER"
export KUBECONFIG="/home/scot4/.kube/config"
echo "~~~"
echo "~~~ Modify Helm Upgrade"
echo "~~~"
echo "~~~ Default Helm Command:"
echo "~~~     $BASE $OPTS $INCL $DANGER $SUFFIX"
echo "~~~"

read -p "Edit parameters: " -e -i "$PARAMS" NEWPARAMS
source ~scot4/.bashrc

echo "Executing "
echo "whoami = $(whoami)"
echo "home = $HOME"
echo "KUBECONFIG = $KUBECONFIG"
echo "$BASE $OPTS $NEWPARAMS $SUFFIX"

"$SCRIPT_DIR/inst_backfill_flair_mojo_secret.sh"

$BASE $OPTS $NEWPARAMS $SUFFIX

"$SCRIPT_DIR/inst_cleanup_legacy_meilisearch_secrets.sh"
"$SCRIPT_DIR/inst_cleanup_legacy_database_root_secrets.sh"

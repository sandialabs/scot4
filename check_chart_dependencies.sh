#!/bin/bash
set -euo pipefail

CHART_DIR="${1:-./scot4}"
LOCK_FILE="$CHART_DIR/Chart.lock"

if [ ! -f "$LOCK_FILE" ]; then
    echo "ERROR: Missing $LOCK_FILE"
    echo "Run 'helm dependency build $CHART_DIR' and commit Chart.lock plus vendored chart archives before deploying."
    exit 1
fi

if ! compgen -G "$CHART_DIR/charts/nats-*.tgz" > /dev/null; then
    echo "ERROR: Missing vendored NATS chart archive under $CHART_DIR/charts/"
    echo "Run 'helm dependency build $CHART_DIR' and commit the resulting nats-*.tgz before deploying."
    exit 1
fi

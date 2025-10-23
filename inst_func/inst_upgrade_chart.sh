#!/bin/bash
set -x
HELM=/usr/local/bin/helm
export KUBECONFIG="/home/scot4/.kube/config"

$HELM upgrade -n scot4 \
    --install \
    --reset-values \
    -f OS_values.yaml \
    --set scot4.cleanFlairInstall=true \
    --set scot4.wipeApiDatabase=true \
    scot4 ./scot4

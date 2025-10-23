#!/bin/bash
# set -x
NS=$1
KEY=$2
CRT=$3
KCTL="/usr/local/bin/kubectl"
export KUBECONFIG="/home/scot4/.kube/config"

if $KCTL -n scot4 get secret scot4-tls; then
    echo "scot4 tls secret exists"
    exit 0
fi

CMD="create secret tls scot4-tls"
OPTIONS="--key=$KEY --cert=$CRT --namespace $NS"

if $KCTL $CMD $OPTIONS; then
    echo "created scot4-tls secret"
    exit 0
fi

echo "!!! FAILED to create scot4-tls !!!"
exit 1

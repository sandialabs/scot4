#!/bin/bash
set -x
NAMESPACE=$1
KCTL="/usr/local/bin/kubectl"
export KUBECONFIG="/home/scot4/.kube/config"

if $KCTL get ns $NAMESPACE; then

    echo "$NAMESPACE already exists."

else

    if $KCTL create ns $NAMESPACE; then
        echo "Created namespace $NAMESPACE"
    else
        echo "!!! FAILED to CREATE namespace $NAMESPACE !!!"
        exit 1
    fi
fi
exit 0



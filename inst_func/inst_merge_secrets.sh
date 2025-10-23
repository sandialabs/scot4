#!/bin/bash

SECRET=$1
NAME=$2
REPO=$3
SPACE=$4
KCTL=/usr/local/bin/kubectl
export KUBECONFIG="/home/scot4/.kube/config"

if [ "$SECRET" == "x" ] || [ "$NAME" == "x" ] || [ "$REPO" == "x" ]; then
    echo "    Registry Name, Secret, or Password not provided."
    echo "    ...assuming that is because merging this into secrets not necesary"
    exit 0
fi

OPTS="--docker-server $REPO --docker-username $NAME --docker-password $SECRET --namespace $SPACE"
KCMD="create secret docker-registry scot4-image-pull-secret"

if $KCTL $KCMD $OPTS; then
    echo "    merged regstry info into secrets"
else 
    echo "    !!! FAILED to merge registry secrets !!!"
    exit 1
fi
exit 0


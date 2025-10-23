#!/bin/bash

SDURI=$1
BASEDIR=$2
KCTL="/usr/local/bin/kubectl"
export KUBECONFIG="/home/scot4/.kube/config"

GET="-n scot4 get secret scot4-env-secrets"
if $KCTL $GET; then
    echo "scot4-env-secrets already exist"
    exit 0
fi

OPTS=""

if [ "$SDURI" != "x" ]; then
    OPTS="$SDURI"
fi

GENERATE="python3 $BASEDIR/auto_gen_secrets.py $OPTS"

if $GENERATE; then
    echo "secrets generated"
else
    echo "!!! FAILED to generate secrets !!!"
    exit 1
fi

SFILE1="$BASEDIR/scot4/auto_gen_secrets.yaml"
SFILE2="$BASEDIR/scot4/auto_gen_flair_secrets.yaml"

for FILE in $SFILE1 $SFILE2; do
    if $KCTL -n scot4 apply -f $FILE; then
        echo "applied $FILE successfully"
    else
        echo "!!! FAILED to apply $FILE !!!"
        exit 1
    fi
done
exit 0


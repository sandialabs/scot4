#!/bin/bash

/usr/local/bin/helm upgrade \
    -n scot4 \
    --install \
    --reset-values \
    -f OS_values.yaml \
    --set scot4.cleanFlairInstall=false \
    --set scot4.wipeApiDatabase=false \
    scot4 ./scot4

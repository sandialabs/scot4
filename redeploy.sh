#!/bin/bash

/usr/local/bin/helm upgrade \
    -n scot4 \
    --install \
    --reset-values \
    -f OS_values.yaml \
    --set-string scot4.clean_flair_install="false" \
    --set-string scot4.wipe_api_database="false" \
    scot4 ./scot4

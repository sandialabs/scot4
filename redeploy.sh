#!/bin/bash

helm upgrade \
    --kubeconfig /etc/rancher/k3s/k3s.yaml \
    -n scot4 \
    --install \
    --reset-values \
    -f values.yaml \
    -f OS_values.yaml \
    --set-string scot4.clean_flair_install="false" \
    --set-string scot4.wipe_api_database="false" \
    scot4 .

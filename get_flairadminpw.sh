#!/bin/bash
echo ""
kubectl -n scot4 get secrets scot4-flair-secrets -o jsonpath='{.data.S4FLAIR_ADMIN_PASS}' | base64 --decode
echo ""

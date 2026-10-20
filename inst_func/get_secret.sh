#!/bin/bash

echo "Select Secret to Retrieve"
echo ""
echo ""
K="/usr/bin/kubectl -n scot4 get secrets"

PS3="Select account > "

select opt in FIRST_SUPERUSER_PASSWORD S4FLAIR_ADMIN_PASS API_SERVICE_PASSWORD FLAIR_SERVICE_PASSWORD AUTH_CALLOUT_PASSWORD quit; do
    case $opt in
        FIRST_SUPERUSER_PASSWORD)
            $K scot4-env-secrets -o jsonpath='{.data.FIRST_SUPERUSER_PASSWORD}' | base64 --decode; echo ""
            ;;
        S4FLAIR_ADMIN_PASS)
            $K scot4-flair-secrets -o jsonpath='{.data.S4FLAIR_ADMIN_PASS}' | base64 --decode; echo ""
            ;;
        API_SERVICE_PASSWORD)
            $K scot4-nats-secrets -o jsonpath='{.data.API_SERVICE_PASSWORD}' | base64 --decode; echo ""
            ;;
        FLAIR_SERVICE_PASSWORD)
            $K scot4-nats-secrets -o jsonpath='{.data.FLAIR_SERVICE_PASSWORD}' | base64 --decode; echo ""
            ;;
        AUTH_CALLOUT_PASSWORD)
            $K scot4-nats-secrets -o jsonpath='{.data.AUTH_CALLOUT_PASSWORD}' | base64 --decode; echo ""
            ;;
    esac
done

#!/bin/bash

echo "Select Secret to Retrieve"
echo ""
echo ""
K="/usr/bin/kubectl -n scot4 get secrets"

PS3="Select account > "

select opt in FIRST_SUPERUSER_PASSWORD S4FLAIR_ADMIN_PASS quit; do
    case $opt in
        FIRST_SUPERUSER_PASSWORD)
            $K scot4-env-secrets -o jsonpath='{.data.FIRST_SUPERUSER_PASSWORD}'|base64 --decode; echo ""
            ;;
        S4FLAIR_ADMIN_PASS)
            $K scot4-flair-secrets -o jsonpath='{.data.S4FLAIR_ADMIN_PASS}' | base64 --decode; echo ""
            ;;
    esac
done


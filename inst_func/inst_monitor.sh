#!/bin/bash

source ~scot4/.bashrc
KUBECTL="/usr/local/bin/kubectl"
CONTINUE="YES"
while [ "$CONTINUE" == "YES" ]; do
    clear
    date
    echo "POD Status"
    ehoo ""
    $KUBECTL get pods

    read -t 10 -p "Press any key to quit" -n 1 GO

    if [ $? -eq 0 ]; then
        CONTINUE="NO"
    fi
done

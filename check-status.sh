#!/bin/bash

# Remote server details
REMOTE_USER="root"
REMOTE_HOST="68.183.42.84"

RED="\e[31m"
GREEN="\e[32"
ENDCOLOR="\e[0m"

# List of services to check
SERVICES=("otnode" "ka-mining-api" "airflow-scheduler" "edge-node-backend" "auth-service")

animate_dots() {
    local pid=$1
    local delay=0.2
    local dots=""

    while ps -p $pid &>/dev/null; do
        dots+="."
        echo -ne "\r$2 $dots"
        sleep $delay
    done

}
echo -e "Checking services on $REMOTE_HOST...\n"

for SERVICE in "${SERVICES[@]}"; do
    echo -ne "$SERVICE ..."

    ssh $REMOTE_USER@$REMOTE_HOST "systemctl is-active $SERVICE" &>/tmp/service_status_$SERVICE &
    PID=$!

    animate_dots $PID $SERVICE

    wait $PID
    STATUS=$(cat /tmp/service_status_$SERVICE)
    
    echo -ne "\r$SERVICE ... "
    if [[ "$STATUS" == "active" ]]; then
        echo -e "${GREEN}active\e${ENDCOLOR}" 
    else
        echo -e "${RED}inactive\e${NOCOLOR}"
    fi
done

# Clean up
rm -f /tmp/service_status_*

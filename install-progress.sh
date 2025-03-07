#!/bin/bash

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
RESET="$(tput sgr0)"

SCRIPT_NAME="edge-node-installer.sh"

if [ -f .env ]; then
  source .env
else
  echo "Config file not found!"
  exit 1
fi

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

check_script_progress() {
    local progress=""
    i=1
    sp=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while true; do
        # Print spinning animation
        printf "\rSetup in progress ${sp[i % ${#sp[@]}]}"
        sleep 0.1
        ((i++))  # Increment counter correctly

        # Check process every 10 loops
        if (( i % 10 == 0 )); then
            PID=$(ssh $REMOTE_USER@$REMOTE_HOST "pgrep -f edge-node-installer.sh");

            if [ -z "$PID" ]; then
                printf "\b%s" "... DONE"
                break
            fi
        fi
    done

    echo -e "\n\n=========== SERVICE STATUS ==========="

    for SERVICE in "${SERVICES[@]}"; do
        echo -ne "$SERVICE ..."

        ssh $REMOTE_USER@$REMOTE_HOST "systemctl is-active $SERVICE" &>/tmp/service_status_$SERVICE &
        PID=$!

        animate_dots $PID $SERVICE

        wait $PID
        STATUS=$(cat /tmp/service_status_$SERVICE)
        
        echo -ne "\r$SERVICE ... "
        if [[ "$STATUS" == "active" ]]; then
            printf '%s%s%s\n' $GREEN 'active' $RESET
        else
            printf '%s%s%s\n' $RED 'inactive' $RESET
        fi
    done
}

check_script_progress


# Clean up
rm -f /tmp/service_status_*
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


SPINNERS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

SERVICES=(
    "otnode"
    "ka-mining-api"
    "edge-node-backend"
    "auth-service"
    "nginx"
)
SERVICE_STATUSES=("in-progress" "in-progress" "in-progress" "in-progress" "in-progress")

clear
echo -e "\e[?25l"

i=0
while true; do
    for idx in "${!SERVICES[@]}"; do
        service="${SERVICES[$idx]}"
        tput cup $idx 0  
        # Display service status and spinner if in progress
        if [[ "${SERVICE_STATUSES[$idx]}" == "in-progress" ]]; then
            echo -ne "$service  ${SPINNERS[$i % ${#SPINNERS[@]}]} \r"
        else
            echo -ne "$service  ${SERVICE_STATUSES[$idx]} \r"
        fi
    done

    ((i++))
    sleep 0.1

    if (( i % 25 == 0 )); then
        # Check if the script is still running
        PARENT_PID=$(ssh $REMOTE_USER@$REMOTE_HOST "pgrep -f $SCRIPT_NAME" 2>/dev/null)
        
        if [ -z "$PARENT_PID" ]; then
            # Check the service status for each service
            for idx in "${!SERVICES[@]}"; do
                tput cup $idx 0
                service="${SERVICES[$idx]}"
                status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_HOST "systemctl is-active $service" 2>/dev/null)

                if [[ "$status" == "active" ]]; then
                    SERVICE_STATUSES[$idx]="${GREEN}active${RESET}"
                else
                    SERVICE_STATUSES[$idx]="${RED}inactive${RESET}"
                fi

                echo -e "$service ... ${SERVICE_STATUSES[$idx]}"
            done

            tput cnorm
            echo -e "\e[?25h" 
            exit 0
        fi
    fi
done

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

# Spinner animation frames
SPINNERS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# Store service statuses
SERVICES=(
    "otnode"
    "ka-mining-api"
    "edge-node-backend"
    "auth-service"
    "nginx"
)
SERVICE_STATUSES=("in-progress" "in-progress" "in-progress" "in-progress" "in-progress")

# Function to check service status
check_service_status() {
    local SERVICE=$1
    STATUS=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_HOST "systemctl is-active $SERVICE" 2>/dev/null)

    if [[ "$STATUS" == "active" ]]; then
        SERVICE_STATUSES[$SERVICE]="${GREEN}active${RESET}"
    else
        SERVICE_STATUSES[$SERVICE]="${RED}inactive${RESET}"
    fi
}

# Clear screen
clear

# Start the animation loop
i=0
while true; do
    # Update the screen with spinner
    for idx in "${!SERVICES[@]}"; do
        service="${SERVICES[$idx]}"
        tput cup $idx 0  # Move cursor to the correct line

        # Display service status and spinner if in progress
        if [[ "${SERVICE_STATUSES[$idx]}" == "in-progress" ]]; then
            echo -ne "$service  ${SPINNERS[$i % ${#SPINNERS[@]}]} \r"
        else
            echo -ne "$service  ${SERVICE_STATUSES[$idx]} \r"
        fi
    done

    # Increment the spinner index and sleep
    ((i++))
    sleep 0.1

    # Every 100 iterations, check service statuses
    if (( i % 100 == 0 )); then
        # Check if the script is still running
        PARENT_PID=$(ssh $REMOTE_USER@$REMOTE_HOST "pgrep -f $SCRIPT_NAME" 2>/dev/null)
        
        if [ -z "$PARENT_PID" ]; then
            # Check the service status for each service
            for idx in "${!SERVICES[@]}"; do
                service="${SERVICES[$idx]}"
                status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_HOST "systemctl is-active $service" 2>/dev/null)

                if [[ "$status" == "active" ]]; then
                    SERVICE_STATUSES[$idx]="${GREEN}active${RESET}"
                else
                    SERVICE_STATUSES[$idx]="${RED}inactive${RESET}"
                fi
            done

            # Clear the screen and print the final status of all services
            clear
            for idx in "${!SERVICES[@]}"; do
                service="${SERVICES[$idx]}"
                echo -e "$service  ${SERVICE_STATUSES[$idx]}"
            done

            # Restore the cursor and exit
            tput cnorm
            exit 0
        fi
    fi
done

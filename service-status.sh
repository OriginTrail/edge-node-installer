#!/usr/bin/env bash

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
RESET="$(tput sgr0)"

SCRIPT_NAME="edge-node-installer.sh"

if [ -f .env ]; then
  source .env
else
  echo "Config file not found. Make sure you have configured your .env file!"
  exit 1
fi


SPINNERS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

SERVICES=(
    "otnode"
    "ka-mining-api"
    "edge-node-api"
    "auth-service"
    "drag-api"
    "nginx"
)
SERVICE_STATUSES=("in-progress" "in-progress" "in-progress" "in-progress" "in-progress" "in-progress")

clear
echo -e "${BOLD}===========================${RESET}"
echo -e "   ${BOLD}Services status...${RESET} 🚀    "
echo -e "${BOLD}===========================${RESET}\n"
echo -e "\e[?25l"

is_local=true
if [ -n "$REMOTE_USER" ] && [ -n "$REMOTE_HOST" ]; then
    is_local=false
fi


i=0
while true; do
    for idx in "${!SERVICES[@]}"; do
        service="${SERVICES[$idx]}"
        tput cup $((idx + 3)) 0


        if [[ $service == "nginx" ]]; then
            service="edge-node-ui"
        fi

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
        if [ "$is_local" == true ]; then
            PARENT_PID=$(pgrep -f "$SCRIPT_NAME" 2>/dev/null)
        else 
            PARENT_PID=$(ssh "$REMOTE_USER@$REMOTE_HOST" "pgrep -f '$SCRIPT_NAME'" 2>/dev/null)
        fi
        
        if [ -z "$PARENT_PID" ]; then
            # Timeout to allow services to restart
            sleep 2;

            # Check the service status for each service
            for idx in "${!SERVICES[@]}"; do
                tput cup $((idx + 3)) 0
                service="${SERVICES[$idx]}"

                if [ "$is_local" == true ]; then
                    status=$(systemctl is-active "$service" 2>/dev/null)
                else
                    status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_HOST "systemctl is-active $service" 2>/dev/null)
                fi

                if [[ "$status" == "active" ]]; then
                    STATUS_TEXT=" ... ${GREEN}Active${RESET}"
                else
                    STATUS_TEXT=" ... ${RED}Inactive${RESET}"
                fi

                if [[ $service == "nginx" ]]; then
                    service="edge-node-ui"
                fi

                echo -e "${BOLD}$service${RESET}  $STATUS_TEXT"
            done

            tput cnorm
            echo -e "\e[?25h" 
            exit 0
        fi
    fi
done

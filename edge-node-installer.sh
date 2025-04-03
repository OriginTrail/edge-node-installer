#!/usr/bin/env bash

# Load the configuration variables
if [ -f .env ]; then
  source .env
else
  echo "Config file not found!"
  exit 1
fi

SERVER_IP="127.0.0.1"
OS=$(uname -s)
if [ "$OS" == "Darwin" ]; then
    echo "Detected macOS"
    source './macos.sh'

    if [ "$DEPLOYMENT_MODE" = "production" ]; then
        SERVER_IP=$(ipconfig getifaddr en0)
    fi

elif [ "$OS" == "Linux" ]; then
    echo "Detected Linux"

    # Check if script is run as root
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root. Please switch to the root user and try again."
        exit 1
    fi

    if [ "$DEPLOYMENT_MODE" = "production" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi

    source './linux.sh'
    check_system_version

else
    echo "Unsupported OS: $OS"
    exit 1
fi

# If PUBLIC_IP and SERVER_NAME differ, set SERVER_NAME to PUBLIC_IP
PUBLIC_IP=$(curl -s ifconfig.me)
if [ "$PUBLIC_IP" != "$SERVER_NAME" ]; then
    $SERVER_NAME="$PUBLIC_IP"
fi

mkdir -p "$EDGE_NODE_DIR"
SHELL_RC="$HOME/.bashrc"

# Creates files if they don't exist
touch "$SHELL_RC"
touch "$HOME/.bash_profile"

source ./common.sh
source ./engine-node-config-generator.sh

# configure edge-node components github repositories
repos_keys=("edge_node_knowledge_mining" "edge_node_auth_service" "edge_node_drag" "edge_node_api" "edge_node_interface")
repos_values=(
  "${EDGE_NODE_KNOWLEDGE_MINING_REPO:-https://github.com/OriginTrail/edge-node-knowledge-mining}"
  "${EDGE_NODE_AUTH_SERVICE_REPO:-https://github.com/OriginTrail/edge-node-authentication-service}"
  "${EDGE_NODE_DRAG_REPO:-https://github.com/OriginTrail/edge-node-drag}"
  "${EDGE_NODE_API_REPO:-https://github.com/OriginTrail/edge-node-api}"
  "${EDGE_NODE_UI_REPO:-https://github.com/OriginTrail/edge-node-interface}"
)

# Function to get the repo URL by key
get_repo_url() {
  local key="$1"
  for (( i=0; i<${#repos_keys[@]}; i++ )); do
    if [ "${repos_keys[$i]}" == "$key" ]; then
      echo "${repos_values[$i]}"
      return
    fi
  done
  echo "Repository not found" >&2
  return 1
}

# Add credentials if provided
if [ -n "$REPOSITORY_USER" ] && [ -n "$REPOSITORY_AUTH" ]; then
  credentials="${REPOSITORY_USER}:${REPOSITORY_AUTH}@"
  for (( i=0; i<${#repos_values[@]}; i++ )); do
    repos_values[$i]="${repos_values[$i]//https:\/\//https://$credentials}"
  done
fi


# ####### todo: Update ot-node branch
# ####### todo: Replace add .env variables to .origintrail_noderc
setup
setup_auth_service && \
setup_edge_node_api && \
setup_edge_node_ui && \
setup_drag_api && \
setup_ka_mining_api && \
setup_airflow_service

if [ "$DEPLOYMENT_MODE" = "production" ]; then
    finish_install
fi

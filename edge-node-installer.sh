#!/usr/bin/env bash

# Load the configuration variables
if [ -f .env ]; then
  source .env
else
  echo "Config file not found!"
  exit 1
fi

OS=$(uname -s)
SERVER_IP="127.0.01"
if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS"
    source './macos.sh'

    if [[ $DEPLOYMENT_METHOD = "production" ]]; then
        SERVER_IP=$(ipconfig getifaddr en0)
    fi

elif [[ "$OS" == "Linux" ]]; then
    echo "Detected Linux"

    # Check if script is run as root
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root. Please switch to the root user and try again."
        exit 1
    fi

    if [[ $DEPLOYMENT_METHOD = "production" ]]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi

    source './linux.sh'
    check_system_version
   
else
    echo "Unsupported OS: $OS"
    exit 1
fi

mkdir -p $EDGE_NODE_DIR
SHELL_RC="$HOME/.bashrc"

# Creates files if they don't exist
touch "$SHELL_RC"
touch "$HOME/.bash_profile"

source ./common.sh
source ./engine-node-config-generator.sh

#configure edge-node components github repositories
declare -A repos=(
  ["edge_node_knowledge_mining"]=${EDGE_NODE_KNOWLEDGE_MINING_REPO:-"https://github.com/OriginTrail/edge-node-knowledge-mining"}
  ["edge_node_auth_service"]=${EDGE_NODE_AUTH_SERVICE_REPO:-"https://github.com/OriginTrail/edge-node-authentication-service"}
  ["edge_node_drag"]=${EDGE_NODE_DRAG_REPO:-"https://github.com/OriginTrail/edge-node-drag"}
  ["edge_node_api"]=${EDGE_NODE_API_REPO:-"https://github.com/OriginTrail/edge-node-api"}
  ["edge_node_interface"]=${EDGE_NODE_UI_REPO:-"https://github.com/OriginTrail/edge-node-interface"}
)

if [[ -n "$REPOSITORY_USER" && -n "$REPOSITORY_AUTH" ]]; then
  credentials="${REPOSITORY_USER}:${REPOSITORY_AUTH}@"
  for key in "${!repos[@]}"; do
    repos[$key]="${repos[$key]//https:\/\//https://$credentials}"
  done
fi

# ####### todo: Update ot-node branch
# ####### todo: Replace add .env variables to .origintrail_noderc
setup
setup_auth_service && \
setup_edge_node_api && \
setup_edge_node_ui && \
setup_drag_api && \
setup_ka_minging_api && \
setup_airflow_service

if [[ $DEPLOYMENT_METHOD = "development" ]]; then
    finish_install
fi
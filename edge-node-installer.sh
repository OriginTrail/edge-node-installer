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
if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS"
    source './macos.sh'

    if [[ $DEPLOYMENT_MODE = "production" ]]; then
        SERVER_IP=$(ipconfig getifaddr en0)
    fi

    if [[ "$(bash --version | head -n 1 | awk '{print $4}')" < "5.2" ]]; then
      echo "Bash 5.2 or higher is required. Attempting to install via Homebrew..."
      
      # Check if Homebrew is installed
      if ! command -v brew &>/dev/null; then
        echo "Error: Homebrew is not installed. Please install it first: https://brew.sh/"
        exit 1
      fi

      # Install Bash 5.2
      brew install bash

      # Get new Bash path
      NEW_BASH_PATH=$(brew --prefix)/bin/bash

      # Add it to /etc/shells if not present
      if ! grep -Fxq "$NEW_BASH_PATH" /etc/shells; then
        echo "$NEW_BASH_PATH" | sudo tee -a /etc/shells
      fi

      # Set default shell
      chsh -s "$NEW_BASH_PATH"
      echo "Bash 5.2 installed. Restart your terminal and run the script again."
      exit 0
    fi

elif [[ "$OS" == "Linux" ]]; then
    echo "Detected Linux"

    # Check if script is run as root
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root. Please switch to the root user and try again."
        exit 1
    fi

    if [[ $DEPLOYMENT_MODE = "production" ]]; then
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

if [[ $DEPLOYMENT_MODE = "production" ]]; then
    finish_install
fi
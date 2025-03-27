#!/bin/sh

# Load the configuration variables
if [ -f .env ]; then
  source .env
else
  echo "Config file not found!"
  exit 1
fi

OS=$(uname -s)
if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS"
    source './macos.sh'

elif [[ "$OS" == "Linux" ]]; then
    echo "Detected Linux"

    # Check if script is run as root
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root. Please switch to the root user and try again."
        exit 1
    fi

    source './linux.sh'
    check_system_version
    
else
    echo "Unsupported OS: $OS"
    exit 1
fi

mkdir -p $EDGE_NODE_DIR

SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == "/bin/bash" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

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

OTNODE_DIR="$EDGE_NODE_DIR/ot-node"
if [ -d "$OTNODE_DIR" ]; then
    echo -e "\n⚠️  The DKG Node directory '$OTNODE_DIR' already exists."
    echo "Please choose one of the following options before continuing:"
    echo "1) Delete the existing directory and proceed with installation."
    echo "2) Create a backup of the existing directory and proceed with installation."
    echo "3) Abort the installation."
    
    while true; do
        read -p "Enter your choice (1/2/3) [default: 3]: " choice
        choice=${choice:-3}  # Default to '3' (Abort) if the user presses Enter without input

        case "$choice" in
            1)
                echo "Deleting the existing directory '$OTNODE_DIR'..."
                rm -rf "$OTNODE_DIR"
                echo "Directory deleted. Proceeding with installation."
                break
                ;;
            2)
                echo "Creating a backup of the existing directory..."
                timestamp=$(date +"%Y%m%d%H%M%S")
                backup_dir="/root/ot-node_backup_$timestamp"
                mv "$OTNODE_DIR" "$backup_dir"
                echo "Backup created at: $backup_dir"
                echo "Proceeding with installation."
                break
                ;;
            3)
                echo "Installation aborted."
                exit 1
                ;;
            *)
                echo -e "\n❌ Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
fi

# Export server IP
SERVER_IP=$(hostname -I | awk '{print $1}')


# ####### todo: Update ot-node branch
# ####### todo: Replace add .env variables to .origintrail_noderc
setup
setup_auth_service && \
setup_edge_node_api && \
setup_edge_node_ui && \
setup_drag_api && \
setup_ka_minging_api && \
setup_airflow_service && \

if [ $DEPLOYMENT_METHOD = "development" ]; then
    check_service_status
fi
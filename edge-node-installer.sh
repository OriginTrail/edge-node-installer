#!/bin/sh

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please switch to the root user and try again."
    exit 1
fi

# Load the configuration variables
if [ -f .env ]; then
  source .env
else
  echo "Config file not found!"
  exit 1
fi

OTNODE_DIR=""
OS=$(uname -s)
if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS"
    source './macos.sh'
    OTNODE_DIR="$HOME/ot-node"

elif [[ "$OS" == "Linux" ]]; then
    echo "Detected Linux"
    source './linux.sh'
    check_system_version
    OTNODE_DIR="/root/ot-node"

else
    echo "Unsupported OS: $OS"
    exit 1
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


# Export server IP
SERVER_IP=$(hostname -I | awk '{print $1}')



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

check_folder() {
    if [ -d "$1" ]; then
        echo "Note: It is recommended to delete all directories created by any previous installer executions before running the DKG Edge Node installer. This helps to avoid potential conflicts and issues during the installation process."
        read -p "Directory $1 already exists. Do you want to delete and clone again? (yes/no) [default: no]: " choice
        choice=${choice:-no}  # Default to 'no' if the user presses Enter without input

        if [ "$choice" == "yes" ]; then
            rm -rf "$1"
            echo "Directory $1 deleted."
        else
            echo "Skipping clone for $1."
            return 1
        fi
    fi
    return 0
}

create_env_file() {
    cat <<EOL > $1/.env
NODE_ENV=development
DB_USERNAME=root
DB_PASSWORD=otnodedb
DB_DATABASE=$2
DB_HOST=127.0.0.1
DB_DIALECT=mysql
PORT=$3
UI_ENDPOINT=http://$SERVER_IP
UI_SSL=false
EOL
}

install_python() {
    # Install Python 3.11.7
    # Step 1: Install pyenv
    curl https://pyenv.run | bash

    # Step 2: Add pyenv to shell configuration files (.bashrc and .bash_profile)
    echo -e '\n# Pyenv setup\nexport PATH="$HOME/.pyenv/bin:$PATH"\neval "$(pyenv init --path)"\neval "$(pyenv init -)"\n' >> ~/.bashrc
    echo -e '\n# Pyenv setup\nexport PATH="$HOME/.pyenv/bin:$PATH"\neval "$(pyenv init --path)"\neval "$(pyenv init -)"\n' >> ~/.bash_profile

    # Step 3: Source shell configuration files
    source ~/.bashrc
    source ~/.bash_profile

    # Step 4: Ensure pyenv is loaded in the current shell
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"

    # Step 5: Install Python 3.11.7 and set it as global version
    pyenv install 3.11.7
    pyenv global 3.11.7

    # Step 6: Verify installation
    pyenv --version
    python --version
}



# ####### todo: Update ot-node branch
# ####### todo: Replace add .env variables to .origintrail_noderc

setup && \
setup_auth_service && \
setup_edge_node_api && \
setup_edge_node_ui && \
setup_drag_api && \
setup_ka_minging_api && \
setup_airflow_service && \
check_service_status

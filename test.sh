#!/bin/bash env

EDGE_NODE_INSTALLER_DIR=$(pwd)
EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"

# Services
AUTH_SERVICE="$EDGE_NODE_DIR/edge-node-auth-service"
API_SERVICE="$EDGE_NODE_DIR/edge-node-api"
DRAG_API="$EDGE_NODE_DIR/drag-api"
KA_MINING_API="$EDGE_NODE_DIR/ka-mining-api"
EDGE_NODE_API="$EDGE_NODE_DIR/edge-node-api"
EDGE_NODE_UI="$EDGE_NODE_DIR/edge-node-ui"


repos_keys=("edge_node_knowledge_mining" "edge_node_auth_service" "edge_node_drag" "edge_node_api" "edge_node_interface")
repos_values=(
  "${EDGE_NODE_KNOWLEDGE_MINING_REPO:-https://github.com/OriginTrail/edge-node-knowledge-mining}"
  "${EDGE_NODE_AUTH_SERVICE_REPO:-https://github.com/OriginTrail/edge-node-authentication-service}"
  "${EDGE_NODE_DRAG_REPO:-https://github.com/OriginTrail/edge-node-drag}"
  "${EDGE_NODE_API_REPO:-https://github.com/OriginTrail/edge-node-api}"
  "${EDGE_NODE_UI_REPO:-https://github.com/OriginTrail/edge-node-interface}"
)

if [ -f .env ]; then
  source .env
else
  echo "Config file not found!"
  exit 1
fi


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

# Supported blockchains
blockchain_keys=(
  "neuroweb-mainnet" "neuroweb-testnet"
  "base-mainnet" "base-testnet"
  "gnosis-mainnet" "gnosis-testnet")
blockchain_values=(
  "otp:2043" "otp:20430"
  "base:8453" "base:84532" 
  "gnosis:100" "gnosis:10200"
)

get_blockchain_config() {
  local key="$1"
  for (( i=0; i<${#blockchain_keys[@]}; i++ )); do
    if [ "${blockchain_values[$i]}" == "$key" ]; then
      echo "${blockchain_values[$i]}"
      return
    fi
  done
  echo "Blockchain not found" >&2
  return 1
}

source ./common.sh


if ! command -v nvm &>/dev/null; then
    export NVM_DIR="$HOME/.nvm"
    if [ ! -d "$NVM_DIR" ]; then
        echo "NVM is not installed. Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
    fi

    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
fi


setup_auth_service() {
    echo get_blockchain_config "$DEFAULT_PUBLISH_BLOCKCHAIN-$BLOCKCHAIN_ENVIRONMENT"


    echo "Setting up Authentication Service..."
    if check_folder "$AUTH_SERVICE"; then
        git clone "$(get_repo_url edge_node_auth_service)" "$AUTH_SERVICE"

        cd $AUTH_SERVICE
        git checkout main

        cat <<EOL > $AUTH_SERVICE/.env
SECRET="$(openssl rand -hex 64)"
JWT_SECRET="$(openssl rand -hex 64)"
NODE_ENV=development
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_DATABASE=edge-node-auth-service
DB_HOST=127.0.0.1
DB_DIALECT=mysql
PORT=3001
UI_ENDPOINT=http://$SERVER_IP
UI_SSL=false
EOL

        rm -rf node_modules package-lock.json
        npm cache clean --force
        # Install dependencies
        nvm exec 22.9.0 npm install

        # Setup database
        yes | npx sequelize-cli db:migrate
        yes | npx sequelize-cli db:seed:all

        SQL_FILE="$AUTH_SERVICE/UserConfig.sql"
        TEMP_SQL_FILE="$AUTH_SERVICE/UserConfig_temp.sql"

        # Replace 'localhost' with SERVER_IP in SQL file
        sed "s/localhost/$SERVER_IP/g" "$SQL_FILE" > "$TEMP_SQL_FILE"

        # Execute SQL file on MySQL database
        mysql -u "root" -p"$DB_PASSWORD" "edge-node-auth-service" < "$TEMP_SQL_FILE"

        # Clean up temp file
        rm "$TEMP_SQL_FILE"

        publishing_blockchain=$(get_blockchain_config "$DEFAULT_PUBLISH_BLOCKCHAIN-$BLOCKCHAIN_ENVIRONMENT")

        mysql -u "root" -p"$DB_PASSWORD" "edge-node-auth-service" < "$TEMP_SQL_FILE"
        mysql -u "root" -p"$DB_PASSWORD" "edge-node-auth-service" -e \
            "DELETE FROM user_wallets WHERE user_id = '1';"

        values=""
        for i in 01 02 03; do
            public_key="PUBLISH_WALLET_${i}_PUBLIC_KEY"
            private_key="PUBLISH_WALLET_${i}_PRIVATE_KEY"

            if [[ -n "${!public_key}" && -n "${!private_key}" ]]; then
                if [[ -n "$values" ]]; then
                    values="$values, ('1, ${!public_key}', '${!private_key}, ${publishing_blockchain}')"
                else
                    values="('1, ${!public_key}', '${!private_key}, ${publishing_blockchain}')"
                fi
            fi
        done

        if [[ -n "$values" ]]; then
            query="INSERT INTO your_table (public_key, private_key) VALUES $values;"
            mysql -u root -p"${DB_PASSWORD}" "user_wallets" -e "$query"
            echo "Wallets updated successfully."
        fi

        echo "User config updated successfully."
    fi;

    if [[ "${DEPLOYMENT_MODE,,}" = "production" ]]; then
        cat <<EOL > /etc/systemd/system/auth-service.service
[Unit]
Description=Edge Node Authentication Service
After=network.target

[Service]
ExecStart=$HOME/.nvm/versions/node/v22.9.0/bin/node $AUTH_SERVICE/index.js
WorkingDirectory=$AUTH_SERVICE
EnvironmentFile=$AUTH_SERVICE/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

        systemctl daemon-reload
        systemctl enable auth-service
        systemctl start auth-service
    fi
}

setup_auth_service
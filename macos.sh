#!/usr/bin/env bash

EDGE_NODE_INSTALLER_DIR=$(pwd)
EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"

# Services
AUTH_SERVICE=$EDGE_NODE_DIR/edge-node-authentication-service
API=$EDGE_NODE_DIR/edge-node-api
DRAG_API=$EDGE_NODE_DIR/edge-node-drag
KA_MINING_API=$EDGE_NODE_DIR/edge-node-knowledge-mining
EDGE_NODE_API=$EDGE_NODE_DIR/edge-node-api
EDGE_NODE_UI=/var/www/edge-node-interface

install_blazegraph() {
    BLAZEGRAPH="$OTNODE_DIR/blazegraph"
    mkdir -p "$BLAZEGRAPH"
    wget -O "$BLAZEGRAPH/blazegraph.jar" https://github.com/blazegraph/database/releases/latest/download/blazegraph.jar
}


install_mysql() {
    brew install mysql
    brew services start mysql

    # Wait for MySQL to start
    sleep 5

    # Setup MySQL root user password
    mysql -u root -e "
        ALTER USER 'root'@'localhost'
        IDENTIFIED WITH caching_sha2_password
        BY '${DB_PASSWORD}';
    " || echo "⚠️ Existing password detected, skipping password change"

    mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE operationaldb /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE \`edge-node-auth-service\`;"
    mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE \`edge-node-api\`;"
    mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE drag_logging;"
    mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE ka_mining_api_logging;"


    # NOTE:
    # Default options are read from the following files in the given order:
    # /etc/my.cnf /etc/mysql/my.cnf /opt/homebrew/etc/my.cnf ~/.my.cnf
    MYSQL_CONFIG_FILE="$HOME/.my.cnf"
    if [ -f "$MYSQL_CONFIG_FILE" ]; then
        sed -i '' 's|max_binlog_size|#max_binlog_size|' "$MYSQL_CONFIG_FILE"
        echo -e "disable_log_bin\nwait_timeout = 31536000\ninteractive_timeout = 31536000" >> "$MYSQL_CONFIG_FILE"
    fi
}

install_otnode() {
    check_ot_node_folder
    
    # Setting up node directory
    ARCHIVE_REPOSITORY_URL="github.com/OriginTrail/ot-node/archive"
    BRANCH="v6/release/testnet"
    OT_RELEASE_DIR="ot-node-6-release-testnet"
    
    mkdir -p $OTNODE_DIR

    cd $OTNODE_DIR
    wget https://$ARCHIVE_REPOSITORY_URL/$BRANCH.zip
    unzip *.zip
    rm *.zip

    # Using `jq` to extract the version
    OTNODE_VERSION=$(jq -r '.version' "$OT_RELEASE_DIR/package.json")

    mkdir -p "$OTNODE_DIR/$OTNODE_VERSION"
    mv $OT_RELEASE_DIR/* "$OTNODE_DIR/$OTNODE_VERSION/"
    OUTPUT=$(mv "$OT_RELEASE_DIR"/.* "$OTNODE_DIR/$OTNODE_VERSION" 2>&1)
    rm -rf "$OT_RELEASE_DIR"
    ln -sfn "$OTNODE_DIR/$OTNODE_VERSION" "$OTNODE_DIR/current"

    cd $EDGE_NODE_INSTALLER_DIR

    # Generate engine node config
    generate_engine_node_config "$OTNODE_DIR"
    if [ $? -eq 0 ]; then
        echo "✅ Blockchain config successfully generated at $OTNODE_DIR"
    else
        echo "❌ Blockchain config generation failed!"
    fi

    chmod 600 "$OTNODE_DIR/.origintrail_noderc"

    # Install dependencies
    cd "$OTNODE_DIR/current" && npm ci --omit=dev --ignore-scripts

    echo "REPOSITORY_PASSWORD=otnodedb" >> "$OTNODE_DIR/current/.env"
    echo "NODE_ENV=testnet" >> "$OTNODE_DIR/current/.env"
}


setup() {
    if ! command -v brew &>/dev/null; then
        echo "❌ Brew must be installed to run this script."
    fi

    # Updating Homebrew and installing dependencies
    brew update
    brew upgrade
    brew install make openssl readline \
      sqlite3 wget unzip curl jq \
      llvm git pkg-config python3 \
      openjdk mysql pkg-config

    # Start Redis
    brew install redis

    if ! command -v nvm &>/dev/null; then
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            echo "NVM is not installed. Installing NVM..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        fi

        if [ -s "$NVM_DIR/nvm.sh" ]; then
            . "$NVM_DIR/nvm.sh"
        fi
    fi

    nvm install 22.9.0
    nvm install 20.18.2
    nvm use 20.18.2
    nvm alias default 20.18.2

    install_otnode
    install_blazegraph
    install_mysql

    echo "✅ Setup completed!"
}

setup_auth_service() {
    echo "Setting up Authentication Service..."

    if check_folder "$AUTH_SERVICE"; then
        git clone "$(get_repo_url edge_node_auth_service)" "$AUTH_SERVICE"

        cd "$AUTH_SERVICE"
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$AUTH_SERVICE/.env"
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

        # Install dependencies
	    rm -rf node_modules package-lock.json
    	npm cache clean --force
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

        mysql -u "root" -p"$DB_PASSWORD" "edge-node-auth-service" -e \
            "DELETE FROM user_wallets WHERE user_id = '1';"

        publishing_blockchain=$(get_blockchain_config ${DEFAULT_PUBLISH_BLOCKCHAIN}-${BLOCKCHAIN_ENVIRONMENT})

        values=""
        for i in 01 02 03; do
            public_key="PUBLISH_WALLET_${i}_PUBLIC_KEY"
            private_key="PUBLISH_WALLET_${i}_PRIVATE_KEY"

            createDate=$(date '+%Y-%m-%d %H:%M:%S')
            if [[ -n "${!public_key}" && -n "${!private_key}" ]]; then
                if [[ -n "$values" ]]; then
                    values="$values, ('1', '${!public_key}', '${!private_key}', '${publishing_blockchain}', '${createDate}', '${createDate}')"
                else
                    values="('1', '${!public_key}', '${!private_key}', '${publishing_blockchain}', '${createDate}', '${createDate}')"
                fi
            fi
        done

        echo $values;
        if [[ -n "$values" ]]; then
            query="INSERT INTO user_wallets (user_id, wallet, private_key, blockchain, createdAt, updatedAt) VALUES $values;"
            mysql -u root -p"${DB_PASSWORD}" "edge-node-auth-service" -e "$query"
            echo "Wallets updated successfully."
        fi

        echo "User config updated successfully."
    fi;
}


setup_edge_node_api() {
    echo "Setting up API Service..."

    if check_folder "$EDGE_NODE_API"; then
        git clone "$(get_repo_url edge_node_api)" "$EDGE_NODE_API"

        cd "$EDGE_NODE_API"
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$EDGE_NODE_API/.env"
NODE_ENV=development
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_DATABASE=edge-node-api
DB_HOST=127.0.0.1
DB_DIALECT=mysql
PORT=3002
AUTH_SERVICE_ENDPOINT=http://$SERVER_IP:3001
UI_ENDPOINT="http://$SERVER_IP"
RUNTIME_NODE_OPERATIONAL_DB_USERNAME=$DB_USERNAME
RUNTIME_NODE_OPERATIONAL_DB_PASSWORD=$DB_PASSWORD
RUNTIME_NODE_OPERATIONAL_DB_DATABASE=operationaldb
RUNTIME_NODE_OPERATIONAL_DB_HOST=127.0.0.1
RUNTIME_NODE_OPERATIONAL_DB_DIALECT=mysql
UI_SSL=false
EOL

        # Install dependencies
	    rm -rf node_modules package-lock.json
    	npm cache clean --force
        nvm exec 20.18.2 npm install

        # Setup database
        npx sequelize-cli db:migrate
    fi
}

setup_edge_node_ui() {
    echo "Setting up Edge Node UI..."

    if [ ! -d "$EDGE_NODE_UI" ]; then
        git clone "$(get_repo_url edge_node_interface)" "$EDGE_NODE_UI"
        
        cd "$EDGE_NODE_UI"
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$EDGE_NODE_UI/.env"
VITE_APP_URL="http://$SERVER_IP"
VITE_APP_NAME="Edge Node"
VITE_AUTH_ENABLED=true
VITE_AUTH_SERVICE_ENDPOINT=http://$SERVER_IP:3001
VITE_EDGE_NODE_BACKEND_ENDPOINT=http://$SERVER_IP:3002
VITE_CHATDKG_API_BASE_URL=http://$SERVER_IP:5002
VITE_APP_ID=edge_node
BASE_URL=http://$SERVER_IP
EOL

        export NVM_DIR="$HOME/.nvm"
        source "$NVM_DIR/nvm.sh"
        nvm use 22.9.0
        rm -rf node_modules package-lock.json
        npm cache clean --force
        npm install && npm run build

        # Install and configure Nginx (if not installed)
        if ! command -v nginx &> /dev/null; then
            brew install nginx
        fi

        static_dir=$(nginx -V 2>&1 | sed -n 's/.*--prefix=\([^ ]*\).*/\1/p' | grep -v '^$')
        EDGE_NODE_UI_STATIC_DIR="${static_dir}/html/edge-node-interface"
        mkdir -p $EDGE_NODE_UI_STATIC_DIR

        cp -R ${EDGE_NODE_UI}/dist/* $EDGE_NODE_UI_STATIC_DIR

        EDGE_NODE_UI_NGINX_SITE="/opt/homebrew/etc/nginx/servers/edge-node-interface"

cat <<EOL > "$EDGE_NODE_UI_NGINX_SITE"
server {
    listen 80;
    listen [::]:80;

    root ${static_dir}/html/edge-node-interface;
    index index.html index.htm;

    error_log /opt/homebrew/var/log/nginx/server_error.log warn;

    server_name _;

    location / {
       try_files $uri $uri/ /index.html;
    }

    access_log /opt/homebrew/var/log/nginx/access.log;
}
EOL

        # Start Nginx
        sudo nginx -t && brew services restart nginx
    fi
}

setup_drag_api() {
    echo "Setting up dRAG API Service..."

    if check_folder "$DRAG_API"; then
        git clone "$(get_repo_url edge_node_drag)" "$DRAG_API"
        cd "$DRAG_API"
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$DRAG_API/.env"
SERVER_PORT=5002
NODE_ENV=production
DB_USER=$DB_USERNAME
DB_PASS=$DB_PASSWORD
DB_HOST=127.0.0.1
DB_NAME=drag_logging
DB_DIALECT=mysql
AUTH_ENDPOINT=http://$SERVER_IP:3001
UI_ENDPOINT="http://$SERVER_IP"
OPENAI_API_KEY="$OPENAI_API_KEY"
EOL

        # Install dependencies
	    rm -rf node_modules package-lock.json
    	npm cache clean --force
        nvm exec 22.9.0 npm install

        # Exec migrations
        npx sequelize-cli db:migrate
    fi
}


setup_ka_mining_api() {
    echo "Setting up KA Mining API Service..."

    if check_folder "$KA_MINING_API"; then
        git clone "$(get_repo_url edge_node_knowledge_mining)" "$KA_MINING_API"
        cd "$KA_MINING_API"
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$KA_MINING_API/.env"
PORT=5005
UI_ENDPOINT=http://$SERVER_IP
AUTH_SERVICE_ENDPOINT=http://$SERVER_IP:3001
KNOWLEDGE_MINING_QUEUE=knowledge-mining-queue
KNOWLEDGE_MINING_CONCURRENCY=20
OPENAI_API_KEY="$OPENAI_API_KEY"
UNSTRUCTURED_API_URL="$UNSTRUCTURED_API_URL"
REDIS_PORT=6379
REDIS_HOST=127.0.0.1
REDIS_USERNAME=
REDIS_PASSWORD=
REDIS_DB=0
ROUTES_PREFIX=/
OTEL_ENABLED=false
OTEL_SERVICE_NAME="edge-node-knowledge-mining"
EOL
    fi

    rm -rf node_modules package-lock.json
    npm cache clean --force
    nvm exec 22.9.0 npm install
}

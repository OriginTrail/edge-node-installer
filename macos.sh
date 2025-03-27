#!/bin/bash

EDGE_NODE_INSTALLER_DIR=$(pwd)
EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"

SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == "/bin/bash" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi


brew install pkg-config

source './common.sh'

install_blazegraph() {
    BLAZEGRAPH_DIR="$OTNODE_DIR/blazegraph"
    mkdir -p "$BLAZEGRAPH_DIR"
    wget -O "$BLAZEGRAPH_DIR/blazegraph.jar" https://github.com/blazegraph/database/releases/latest/download/blazegraph.jar
}


install_mysql() {
    brew install mysql
    brew services start mysql

    # Wait for MySQL to start
    sleep 5

    # Set MySQL root password
    mysql -u root ${DB_ROOT_PASSWORD:+-p$DB_ROOT_PASSWORD} -e \
      "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';"
    mysql -u root -e "CREATE DATABASE operationaldb /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -u root -e "CREATE DATABASE \`edge-node-auth-service\`;"
    mysql -u root -e "CREATE DATABASE \`edge-node-api\`;"
    mysql -u root -e "CREATE DATABASE drag_logging;"
    mysql -u root -e "CREATE DATABASE ka_mining_api_logging;"
    mysql -u root -e "CREATE DATABASE airflow_db;"
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '$DB_PASSWORD';"
    mysql -u root -p"$DB_PASSWORD" -e "flush privileges;"

    # NOTE:
    # Default options are read from the following files in the given order:
    # /etc/my.cnf /etc/mysql/my.cnf /opt/homebrew/etc/my.cnf ~/.my.cnf
    MYSQL_CONFIG_FILE="$HOME/.my.cnf"
    if [[ -f "$MYSQL_CONFIG_FILE" ]]; then
        sed -i '' 's|max_binlog_size|#max_binlog_size|' "$MYSQL_CONFIG_FILE"
        echo -e "disable_log_bin\nwait_timeout = 31536000\ninteractive_timeout = 31536000" >> "$MYSQL_CONFIG_FILE"
    fi
}

install_ot_node() {
    SERVICE="com.origintrail.otnode"
    
    # Setting up node directory
    ARCHIVE_REPOSITORY_URL="github.com/OriginTrail/ot-node/archive"
    BRANCH="v6/release/testnet"
    OT_RELEASE_DIR="ot-node-6-release-testnet"
    
    mkdir -p $OTNODE_DIR

    cd $OTNODE_DIR
    wget https://$ARCHIVE_REPOSITORY_URL/$BRANCH.zip
    unzip *.zip
    rm *.zip

    OTNODE_VERSION=$(jq -r '.version' "$OT_RELEASE_DIR/package.json")

    mkdir -p "$OTNODE_DIR/$OTNODE_VERSION"
    mv $OT_RELEASE_DIR/* "$OTNODE_DIR/$OTNODE_VERSION/"
    OUTPUT=$(mv "$OT_RELEASE_DIR"/.* "$OTNODE_DIR/$OTNODE_VERSION" 2>&1)
    rm -rf "$OT_RELEASE_DIR"
    ln -sfn "$OTNODE_DIR/$OTNODE_VERSION" "$OTNODE_DIR/current"

    cd $EDGE_NODE_INSTALLER_DIR; 

    generate_engine_node_config "$OTNODE_DIR"
    if [[ $? -eq 0 ]]; then
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
    echo "alias otnode-restart='launchctl kickstart -k user/$(id -u)/com.otnode'" >> "$SHELL_RC"
    echo "alias otnode-stop='launchctl unload $HOME/Library/LaunchAgents/com.otnode.plist'" >> "$SHELL_RC"
    echo "alias otnode-start='launchctl load $HOME/Library/LaunchAgents/com.otnode.plist'" >> "$SHELL_RC"
    echo "alias otnode-logs='tail -f $HOME/ot-node/otnode.log'" >> "$SHELL_RC"
    echo "alias otnode-config='nano $HOME/ot-node/.origintrail_noderc'" >> "$SHELL_RC"

    # Install Homebrew if not installed
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Updating Homebrew and installing dependencies
    brew update
    brew upgrade
    brew install make openssl readline \
      sqlite3 wget unzip curl jq \
      llvm tk git pkg-config python3 \
      openjdk redis mysql

    # # # Start Redis
    # TODO: Not sure if needed. Seems like REDIS starts automatically after installation
    # brew services start redis

    # Install Node.js via NVM
    if ! command -v nvm &>/dev/null; then
        echo "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    fi

    nvm install 22.9.0
    nvm install 20.18.2
    nvm use 20.18.2
    nvm alias default 20.18.2

    install_python
    install_ot_node
    install_blazegraph
    install_mysql

    echo "✅ Setup completed!"
}


setup_auth_service() {
    echo "Setting up Authentication Service..."
    
    AUTH_SERVICE_DIR="$EDGE_NODE_DIR/edge-node-auth-service"

    if check_folder "$AUTH_SERVICE_DIR"; then
        git clone "${repos[edge_node_auth_service]}" "$AUTH_SERVICE_DIR"
        cd "$AUTH_SERVICE_DIR"
        git checkout main

        # Create the .env file with required variables
        create_env_file
        cat <<EOL > "$AUTH_SERVICE_DIR/.env"
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
        nvm exec 22.9.0 npm install

        # Setup database
        yes | npx sequelize-cli db:migrate
        yes | npx sequelize-cli db:seed:all

        SQL_FILE="$AUTH_SERVICE_DIR/UserConfig.sql"
        TEMP_SQL_FILE="$AUTH_SERVICE_DIR/UserConfig_temp.sql"

        # Replace 'localhost' with SERVER_IP in SQL file
        sed "s/localhost/$SERVER_IP/g" "$SQL_FILE" > "$TEMP_SQL_FILE"

        # Execute SQL file on MySQL database
        mysql -u "root" -p"$DB_PASSWORD" "edge-node-auth-service" < "$TEMP_SQL_FILE"

        # Clean up temp file
        rm "$TEMP_SQL_FILE"

        echo "User config updated successfully."
    fi;
}


setup_edge_node_api() {
    echo "Setting up API Service..."
    
    API_SERVICE_DIR="$EDGE_NODE_DIR/edge-node-api"

    if check_folder "$API_SERVICE_DIR"; then
        git clone "${repos[edge_node_api]}" "$API_SERVICE_DIR"
        cd "$API_SERVICE_DIR"
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$API_SERVICE_DIR/.env"
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
        nvm exec 20.18.2 npm install

        # Setup database
        npx sequelize-cli db:migrate
    fi
}

setup_edge_node_ui() {
    echo "Setting up Edge Node UI..."

    # Define the target directory
    TARGET_DIR="$EDGE_NODE_DIR/edge-node-ui"

    if [ ! -d "$TARGET_DIR" ]; then
        git clone "${repos[edge_node_interface]}" "$TARGET_DIR"
        cd "$TARGET_DIR" || exit
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$TARGET_DIR/.env"
VITE_APP_URL="http://$SERVER_IP"
VITE_APP_NAME="Edge Node"
VITE_AUTH_ENABLED=true
VITE_AUTH_SERVICE_ENDPOINT=http://$SERVER_IP:3001
VITE_EDGE_NODE_BACKEND_ENDPOINT=http://$SERVER_IP:3002
VITE_CHATDKG_API_BASE_URL=http://$SERVER_IP:5002
VITE_APP_ID=edge_node
BASE_URL=http://$SERVER_IP
EOL

        # Install dependencies and build the UI
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Load NVM

        nvm use 22.9.0
        npm install
        npm run build

        # Install and configure Nginx (if not installed)
        if ! command -v nginx &> /dev/null; then
            brew install nginx
        fi

        # Configure Nginx to serve the UI
        NGINX_CONF="/opt/homebrew/etc/nginx/nginx.conf"
        cp "$NGINX_CONF" "${NGINX_CONF}.bak"

        # Modify the configuration to serve the UI
        cat <<EOL > "$NGINX_CONF"
events {}

http {
    server {
        listen 80;
        server_name localhost;

        location / {
            root $TARGET_DIR/dist;
            index index.html;
            try_files \$uri \$uri/ /index.html;
        }
    }
}
EOL

        # Start Nginx
        sudo nginx -t && sudo brew services restart nginx
    fi
}

setup_drag_api() {
    echo "Setting up dRAG API Service..."

    DRAG_API_DIR="$EDGE_NODE_DIR/drag-api"

    if check_folder "$DRAG_API_DIR"; then
        git clone "${repos[edge_node_drag]}" "$DRAG_API_DIR"
        cd "$DRAG_API_DIR"
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > "$DRAG_API_DIR/.env"
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
        nvm exec 22.9.0 npm install

        # Exec migrations
        npx sequelize-cli db:migrate
    fi
}


setup_ka_mining_api() {
    echo "Setting up KA Mining API Service..."

    KA_MINING_API_DIR="$EDGE_NODE_DIR/ka-mining-api"

    if check_folder "$KA_MINING_API_DIR"; then
        git clone "${repos[edge_node_knowledge_mining]}" "$KA_MINING_API_DIR"
        cd "$KA_MINING_API_DIR"
        git checkout main

        python3 -m venv .venv
        source .venv/bin/activate
        pip install -r requirements.txt

        # Create the .env file with required variables
        cat <<EOL > "$KA_MINING_API_DIR/.env"
PORT=5005
PYTHON_ENV="STAGING"
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_HOST="127.0.0.1"
DB_NAME="ka_mining_api_logging"
DAG_FOLDER_NAME="$KA_MINING_API_DIR/dags"
AUTH_ENDPOINT=http://$SERVER_IP:3001

OPENAI_API_KEY="$OPENAI_API_KEY"
HUGGINGFACE_API_KEY="$HUGGINGFACE_API_KEY"
UNSTRUCTURED_API_URL="$UNSTRUCTURED_API_URL"

ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
BIONTOLOGY_KEY="$BIONTOLOGY_KEY"
MILVUS_USERNAME="$MILVUS_USERNAME"
MILVUS_PASSWORD="$MILVUS_PASSWORD"
MILVUS_URI="$MILVUS_URI"
EOL
    fi
}


setup_airflow_service() {
    echo "Setting up Airflow Service on macOS..."

    AIRFLOW_HOME="$EDGE_NODE_DIR/airflow"
    KA_MINING_API_DIR="$EDGE_NODE_DIR/ka-mining-api"

    export AIRFLOW_HOME="$AIRFLOW_HOME"

    cd "$KA_MINING_API_DIR"

    # Initialize the Airflow database
    airflow db init

    # Create Airflow admin user (TEMPORARY for internal use)
    airflow users create \
        --role Admin \
        --username airflow-administrator \
        --email admin@example.com \
        --firstname Administrator \
        --lastname User \
        --password admin_password

    # Configure Airflow settings in the airflow.cfg file
    sed -i '' \
        -e "s|^dags_folder *=.*|dags_folder = $KA_MINING_API_DIR/dags|" \
        -e "s|^parallelism *=.*|parallelism = 32|" \
        -e "s|^max_active_tasks_per_dag *=.*|max_active_tasks_per_dag = 16|" \
        -e "s|^max_active_runs_per_dag *=.*|max_active_runs_per_dag = 16|" \
        -e "s|^enable_xcom_pickling *=.*|enable_xcom_pickling = True|" \
        -e "s|^load_examples *=.*|load_examples = False|" \
        "$AIRFLOW_HOME/airflow.cfg"

    # Unpause DAGS
    for dag_file in dags/*.py; do
        dag_name=$(basename "$dag_file" .py)
        $KA_MINING_API_DIR/.venv/bin/airflow dags unpause "$dag_name"
    done
}


setup_ka_minging_api() {
    echo "Setting up KA Mining API Service..."

    # Check if the directory exists
    if check_folder "$EDGE_NODE_DIR/ka-mining-api"; then
        git clone "${repos[edge_node_knowledge_mining]}" $EDGE_NODE_DIR/ka-mining-api
        cd $EDGE_NODE_DIR/ka-mining-api
        git checkout main

        python3.11 -m venv .venv
        source .venv/bin/activate
        pip install -r requirements.txt

        # Create the .env file with required variables
        cat <<EOL > $EDGE_NODE_DIR/ka-mining-api/.env
PORT=5005
PYTHON_ENV="STAGING"
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_HOST="127.0.0.1"
DB_NAME="ka_mining_api_logging"
DAG_FOLDER_NAME="$EDGE_NODE_DIR/ka-mining-api/dags"
AUTH_ENDPOINT=http://$SERVER_IP:3001

OPENAI_API_KEY="$OPENAI_API_KEY"
HUGGINGFACE_API_KEY="$HUGGINGFACE_API_KEY"
UNSTRUCTURED_API_URL="$UNSTRUCTURED_API_URL"

ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
BIONTOLOGY_KEY="$BIONTOLOGY_KEY"
MILVUS_USERNAME="$MILVUS_USERNAME"
MILVUS_PASSWORD="$MILVUS_PASSWORD"
MILVUS_URI="$MILVUS_URI"
EOL
    fi
}
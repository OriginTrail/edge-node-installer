#!/bin/bash

SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == "/bin/bash" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi


install_blazegraph() {
    BLAZEGRAPH_DIR="$HOME/ot-node/blazegraph"
    mkdir -p "$BLAZEGRAPH_DIR"

    wget -O "$BLAZEGRAPH_DIR/blazegraph.jar" https://github.com/blazegraph/database/releases/latest/download/blazegraph.jar

    cat <<EOF > "$BLAZEGRAPH_DIR/start_blazegraph.sh"
#!/bin/bash
java -server -Xmx4g -Dbigdata.propertyFile=bigdata.properties -jar "$BLAZEGRAPH_DIR/blazegraph.jar"
EOF
    chmod +x "$BLAZEGRAPH_DIR/start_blazegraph.sh"

    
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.blazegraph.plist"

    cat <<EOF > "$LAUNCH_AGENT"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.blazegraph</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BLAZEGRAPH_DIR/start_blazegraph.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$BLAZEGRAPH_DIR/blazegraph.log</string>
    <key>StandardErrorPath</key>
    <string>$BLAZEGRAPH_DIR/blazegraph.err</string>
</dict>
</plist>
EOF

    # Load the service
    launchctl load -w "$LAUNCH_AGENT"

}


install_mysql() {
    brew install mysql
    brew services start mysql

    # Wait for MySQL to start
    sleep 5

    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';"
    mysql -u root -e "CREATE DATABASE operationaldb /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -u root -e "CREATE DATABASE \`edge-node-auth-service\`;"
    mysql -u root -e "CREATE DATABASE \`edge-node-api\`;"
    mysql -u root -e "CREATE DATABASE drag_logging;"
    mysql -u root -e "CREATE DATABASE ka_mining_api_logging;"
    mysql -u root -e "CREATE DATABASE airflow_db;"
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';"
    mysql -u root -p"$DB_PASSWORD" -e "flush privileges;"

    MYSQL_CONFIG_FILE="/usr/local/etc/my.cnf"
    if [[ -f "$MYSQL_CONFIG_FILE" ]]; then
        sed -i '' 's|max_binlog_size|#max_binlog_size|' "$MYSQL_CONFIG_FILE"
        echo -e "disable_log_bin\nwait_timeout = 31536000\ninteractive_timeout = 31536000" >> "$MYSQL_CONFIG_FILE"
    fi

    echo "REPOSITORY_PASSWORD=otnodedb" >> "$HOME/ot-node/current/.env"
    echo "NODE_ENV=testnet" >> "$HOME/ot-node/current/.env"

    cd "$HOME/ot-node/current"
    npm ci --omit=dev --ignore-scripts

}

install_ot_node() {
    # Setting up node directory
    ARCHIVE_REPOSITORY_URL="github.com/OriginTrail/ot-node/archive"
    BRANCH="v6/release/testnet"
    BRANCH_DIR="$HOME/ot-node-6-release-testnet"
    OTNODE_DIR="$HOME/ot-node"

    cd "$HOME"
    wget https://$ARCHIVE_REPOSITORY_URL/$BRANCH.zip
    unzip *.zip
    rm *.zip

    OTNODE_VERSION=$(jq -r '.version' "$BRANCH_DIR/package.json")
    mkdir -p "$OTNODE_DIR/$OTNODE_VERSION"
    mv "$BRANCH_DIR"/* "$OTNODE_DIR/$OTNODE_VERSION/"
    OUTPUT=$(mv "$BRANCH_DIR"/.* "$OTNODE_DIR/$OTNODE_VERSION/" 2>&1)
    rm -rf "$BRANCH_DIR"
    ln -sfn "$OTNODE_DIR/$OTNODE_VERSION" "$OTNODE_DIR/current"

    # Ensure the directory exists
    mkdir -p "$OTNODE_DIR"

    cd "$HOME/edge-node-installer"
    # Call the function to generate config
    generate_engine_node_config "$OTNODE_DIR"
    if [[ $? -eq 0 ]]; then
        echo "✅ Blockchain config successfully generated at $OTNODE_DIR"
    else
        echo "❌ Blockchain config generation failed!"
    fi

    chmod 600 "$HOME/ot-node/.origintrail_noderc"

    # macOS does not use systemd, so create a LaunchAgent for auto-start
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.otnode.plist"

    cat <<EOF > "$LAUNCH_AGENT"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.otnode</string>
    <key>ProgramArguments</key>
    <array>
        <string>$OTNODE_DIR/current/bin/otnode</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$OTNODE_DIR/otnode.log</string>
    <key>StandardErrorPath</key>
    <string>$OTNODE_DIR/otnode.err</string>
</dict>
</plist>
EOF

    launchctl load -w "$LAUNCH_AGENT"

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
    brew install make openssl readline sqlite3 wget unzip curl jq \
                 llvm tk git pkg-config python3 openjdk redis mysql

    # Start Redis
    brew services start redis

    # Install Node.js via NVM
    if ! command -v nvm &>/dev/null; then
        echo "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
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
    
    AUTH_SERVICE_DIR="$HOME/edge-node-auth-service"

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

    # macOS does not use systemd, so create a LaunchAgent
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.authservice.plist"

    cat <<EOF > "$LAUNCH_AGENT"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.authservice</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.nvm/versions/node/v22.9.0/bin/node</string>
        <string>$AUTH_SERVICE_DIR/index.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$AUTH_SERVICE_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>development</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$AUTH_SERVICE_DIR/auth-service.log</string>
    <key>StandardErrorPath</key>
    <string>$AUTH_SERVICE_DIR/auth-service.err</string>
</dict>
</plist>
EOF

    launchctl load -w "$LAUNCH_AGENT"
}


setup_edge_node_api() {
    echo "Setting up API Service..."
    
    API_SERVICE_DIR="$HOME/edge-node-api"

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

    # macOS does not use systemd, so create a LaunchAgent
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.edge-node-api.plist"

    cat <<EOF > "$LAUNCH_AGENT"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.edge-node-api</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.nvm/versions/node/v22.9.0/bin/node</string>
        <string>$API_SERVICE_DIR/app.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$API_SERVICE_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>development</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$API_SERVICE_DIR/api-service.log</string>
    <key>StandardErrorPath</key>
    <string>$API_SERVICE_DIR/api-service.err</string>
</dict>
</plist>
EOF

    launchctl load -w "$LAUNCH_AGENT"
}

setup_drag_api() {
    echo "Setting up dRAG API Service..."

    DRAG_API_DIR="$HOME/drag-api"

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

    # macOS does not use systemd, so create a LaunchAgent
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.drag-api.plist"

    cat <<EOF > "$LAUNCH_AGENT"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.drag-api</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.nvm/versions/node/v22.9.0/bin/node</string>
        <string>$DRAG_API_DIR/server.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$DRAG_API_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>production</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$DRAG_API_DIR/drag-api.log</string>
    <key>StandardErrorPath</key>
    <string>$DRAG_API_DIR/drag-api.err</string>
</dict>
</plist>
EOF

    launchctl load -w "$LAUNCH_AGENT"
}


setup_ka_mining_api() {
    echo "Setting up KA Mining API Service..."

    KA_MINING_API_DIR="$HOME/ka-mining-api"

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

    # macOS does not use systemd, so create a LaunchAgent
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.ka-mining-api.plist"

    cat <<EOF > "$LAUNCH_AGENT"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ka-mining-api</string>
    <key>ProgramArguments</key>
    <array>
        <string>$KA_MINING_API_DIR/.venv/bin/python</string>
        <string>$KA_MINING_API_DIR/app.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$KA_MINING_API_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PYTHON_ENV</key>
        <string>STAGING</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$KA_MINING_API_DIR/ka-mining-api.log</string>
    <key>StandardErrorPath</key>
    <string>$KA_MINING_API_DIR/ka-mining-api.err</string>
</dict>
</plist>
EOF

    launchctl load -w "$LAUNCH_AGENT"
}


setup_airflow_service() {
    echo "Setting up Airflow Service on macOS..."

    AIRFLOW_HOME="$HOME/airflow"
    KA_MINING_API_DIR="$HOME/ka-mining-api"

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

    # macOS LaunchAgent for Airflow Webserver
    AIRFLOW_WEBSERVER_PLIST="$HOME/Library/LaunchAgents/com.airflow-webserver.plist"

    cat <<EOF > "$AIRFLOW_WEBSERVER_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.airflow-webserver</string>
    <key>ProgramArguments</key>
    <array>
        <string>$KA_MINING_API_DIR/.venv/bin/airflow</string>
        <string>webserver</string>
        <string>--port</string>
        <string>8008</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$KA_MINING_API_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>AIRFLOW_HOME</key>
        <string>$AIRFLOW_HOME</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$KA_MINING_API_DIR/airflow-webserver.log</string>
    <key>StandardErrorPath</key>
    <string>$KA_MINING_API_DIR/airflow-webserver.err</string>
</dict>
</plist>
EOF

    launchctl load -w "$AIRFLOW_WEBSERVER_PLIST"

    # macOS LaunchAgent for Airflow Scheduler
    AIRFLOW_SCHEDULER_PLIST="$HOME/Library/LaunchAgents/com.airflow-scheduler.plist"

    cat <<EOF > "$AIRFLOW_SCHEDULER_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.airflow-scheduler</string>
    <key>ProgramArguments</key>
    <array>
        <string>$KA_MINING_API_DIR/.venv/bin/airflow</string>
        <string>scheduler</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$KA_MINING_API_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>AIRFLOW_HOME</key>
        <string>$AIRFLOW_HOME</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$KA_MINING_API_DIR/airflow-scheduler.log</string>
    <key>StandardErrorPath</key>
    <string>$KA_MINING_API_DIR/airflow-scheduler.err</string>
</dict>
</plist>
EOF

    launchctl load -w "$AIRFLOW_SCHEDULER_PLIST"

    # Unpause DAGS
    for dag_file in dags/*.py; do
        dag_name=$(basename "$dag_file" .py)
        $KA_MINING_API_DIR/.venv/bin/airflow dags unpause "$dag_name"
    done
}


check_service_status() {
    # ------- CHECK STATUSES OF ALL SERVICES ON macOS -------
    echo "Checking services..."

    # Check if the services are loaded (equivalent to 'status' on Linux)
    launchctl list | grep com.airflow-webserver || echo "Airflow Webserver is not running"
    launchctl list | grep com.airflow-scheduler || echo "Airflow Scheduler is not running"
    launchctl list | grep com.edge-node-api || echo "Edge Node API is not running"
    launchctl list | grep com.edge-node-auth-service || echo "Edge Node Auth Service is not running"
    launchctl list | grep com.drag-api || echo "dRAG API is not running"
    launchctl list | grep com.ot-node || echo "OTNode is not running"
    launchctl list | grep com.ka-mining-api || echo "KA Mining API is not running"

    # Restart services by unloading and reloading them using `launchctl`
    echo "======== RESTARTING SERVICES ==========="
    sleep 10

    echo "Restarting services..."

    launchctl bootout system /Library/LaunchAgents/com.airflow-webserver.plist || echo "Failed to stop Airflow Webserver"
    launchctl bootout system /Library/LaunchAgents/com.airflow-scheduler.plist || echo "Failed to stop Airflow Scheduler"
    launchctl bootout system /Library/LaunchAgents/com.edge-node-api.plist || echo "Failed to stop Edge Node API"
    launchctl bootout system /Library/LaunchAgents/com.edge-node-auth-service.plist || echo "Failed to stop Edge Node Auth Service"
    launchctl bootout system /Library/LaunchAgents/com.drag-api.plist || echo "Failed to stop dRAG API"
    launchctl bootout system /Library/LaunchAgents/com.ot-node.plist || echo "Failed to stop OTNode"
    launchctl bootout system /Library/LaunchAgents/com.ka-mining-api.plist || echo "Failed to stop KA Mining API"

    sleep 5

    # Restart the services
    launchctl bootstrap system /Library/LaunchAgents/com.airflow-webserver.plist || echo "Failed to start Airflow Webserver"
    launchctl bootstrap system /Library/LaunchAgents/com.airflow-scheduler.plist || echo "Failed to start Airflow Scheduler"
    launchctl bootstrap system /Library/LaunchAgents/com.edge-node-api.plist || echo "Failed to start Edge Node API"
    launchctl bootstrap system /Library/LaunchAgents/com.edge-node-auth-service.plist || echo "Failed to start Edge Node Auth Service"
    launchctl bootstrap system /Library/LaunchAgents/com.drag-api.plist || echo "Failed to start dRAG API"
    launchctl bootstrap system /Library/LaunchAgents/com.ot-node.plist || echo "Failed to start OTNode"
    launchctl bootstrap system /Library/LaunchAgents/com.ka-mining-api.plist || echo "Failed to start KA Mining API"
}

setup && \
setup_auth_service && \
setup_edge_node_api && \
setup_edge_node_ui && \
setup_drag_api && \
setup_ka_minging_api && \
setup_airflow_service && \
check_service_status




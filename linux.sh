#!/usr/bin/env bash

EDGE_NODE_INSTALLER_DIR=$(pwd)
EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"

# Services
AUTH_SERVICE=$EDGE_NODE_DIR/edge-node-auth-service
API=$EDGE_NODE_DIR/edge-node-api
DRAG_API=$EDGE_NODE_DIR/drag-api
KA_MINING_API=$EDGE_NODE_DIR/ka-mining-api
EDGE_NODE_API=$EDGE_NODE_DIR/edge-node-api
EDGE_NODE_UI=/var/www/edge-node-ui

# Load the configuration variables
if [ -f .env ]; then
  source .env
else
  echo "Config file not found!"
  exit 1
fi

source './common.sh'

# Function to check the Ubuntu version
check_system_version() {
    # Get the Ubuntu version
    ubuntu_version=$(lsb_release -rs)

    # Supported versions
    supported_versions=("20.04" "22.04" "24.04")

    # Check if the current Ubuntu version is supported
    if [[ " ${supported_versions[@]} " =~ " ${ubuntu_version} " ]]; then
        echo "✔️ Supported Ubuntu version detected: $ubuntu_version"
    else
        echo -e "\n❌ Unsupported Ubuntu version detected: $ubuntu_version"
        echo "This installer only supports the following Ubuntu versions:"
        echo "20.04, 22.04, and 24.04."
        echo "Please install the script on a supported version of Ubuntu."
        exit 1
    fi
}

install_blazegraph() {
    BLAZEGRAPH_DIR="$OTNODE_DIR/blazegraph"
    mkdir -p "$BLAZEGRAPH_DIR"
    wget -O "$BLAZEGRAPH_DIR/blazegraph.jar" https://github.com/blazegraph/database/releases/latest/download/blazegraph.jar
    SERVICE=${OTNODE_DIR}/current/installer/data/blazegraph.service
    
    if [[ "${DEPLOYMENT_MODE,,}" = "production" ]]; then
        
        sed -i "s|ExecStart=.*|ExecStart=/usr/bin/java -jar ${OTNODE_DIR}/blazegraph/blazegraph.jar|" ${SERVICE}
        sed -i "s|WorkingDirectory=.*|WorkingDirectory=${OTNODE_DIR}/blazegraph|" ${SERVICE}

        cp ${SERVICE} /etc/systemd/system/

        systemctl daemon-reload
        systemctl enable blazegraph
        systemctl start blazegraph
    fi

    echo "✅ Blazegraph checked. Continuing execution..."
}


install_mysql() {
    apt install tcllib mysql-server -y

    mysql -u root ${DB_ROOT_PASSWORD:+-p$DB_ROOT_PASSWORD} -e \
      "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';"
    mysql -u root -e "CREATE DATABASE operationaldb /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -u root -e "CREATE DATABASE \`edge-node-auth-service\`"
    mysql -u root -e "CREATE DATABASE \`edge-node-api\`;"
    mysql -u root -e "CREATE DATABASE drag_logging;"
    mysql -u root -e "CREATE DATABASE ka_mining_api_logging;"
    mysql -u root -e "CREATE DATABASE airflow_db;"
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '$DB_PASSWORD';"
    mysql -u root -p"$DB_PASSWORD" -e "flush privileges;"

    sed -i 's|max_binlog_size|#max_binlog_size|' /etc/mysql/mysql.conf.d/mysqld.cnf
    echo -e "disable_log_bin\nwait_timeout = 31536000\ninteractive_timeout = 31536000" >> /etc/mysql/mysql.conf.d/mysqld.cnf

    systemctl daemon-reload
    systemctl enable mysql
    systemctl start mysql
}


install_otnode() {
    check_ot_node_folder
    
    # Setting up node directory
    ARCHIVE_REPOSITORY_URL="github.com/OriginTrail/ot-node/archive"
    BRANCH="v6/release/testnet"
    OT_RELEASE_DIR="ot-node-6-release-testnet"
    SERVICE="${OTNODE_DIR}/current/installer/data/otnode.service"
    
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
    
    if [[ "${DEPLOYMENT_MODE,,}" = "production" ]]; then
        sed -i "s|ExecStart=.*|ExecStart=/usr/bin/node ${OTNODE_DIR}/current/index.js|" ${SERVICE}
        sed -E "s|^WorkingDirectory=.*|WorkingDirectory=${OTNODE_DIR}/current|" -i ${SERVICE}
        cp  ${SERVICE} /etc/systemd/system

        systemctl daemon-reload
        systemctl enable otnode.service
        systemctl start otnode.service
    fi
}


setup() {
    #adding aliases to .bashrc:
    echo "alias otnode-restart='systemctl restart otnode.service'" >> ~/.bashrc
    echo "alias otnode-stop='systemctl stop otnode.service'" >> ~/.bashrc
    echo "alias otnode-start='systemctl start otnode.service'" >> ~/.bashrc
    echo "alias otnode-logs='journalctl -u otnode --output cat -f'" >> ~/.bashrc
    echo "alias otnode-config='nano ~/ot-node/.origintrail_noderc'" >> ~/.bashrc

    # Installing prereqs
    export DEBIAN_FRONTEND=noninteractive
    NODEJS_VER="20"
    rm -rf /var/lib/dpkg/lock-frontend

    apt update
    apt upgrade -y
    apt install -y make build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget unzip curl llvm \
    jq libncurses5-dev libncursesw5-dev xz-utils tk-dev \
    libffi-dev liblzma-dev python3-openssl git \
    libmysqlclient-dev pkg-config python3-dev \
    default-jre
    
    # Install redis
    apt install redis-server -y
    systemctl enable redis-server
    systemctl start redis-server

    if ! command -v nvm &>/dev/null; then
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            echo "NVM is not installed. Installing NVM..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        fi

        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    fi


    nvm install 22.9.0 > /dev/null 2>&1
    nvm install 20.18.2 > /dev/null 2>&1

    nvm use 20.18.2 > /dev/null 2>&1
     # Set nodejs v20.18.0 as default and link node to /usr/bin/
    nvm alias default 20.18.2 > /dev/null 2>&1
   
    ln -s $(which node) /usr/bin/ > /dev/null 2>&1
    ln -s $(which npm) /usr/bin/ > /dev/null 2>&1

    install_python
    install_otnode
    install_blazegraph
    install_mysql
}


setup_auth_service() {
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


setup_edge_node_api() {
    echo "Setting up API Service..."
    if check_folder "$EDGE_NODE_API"; then
        git clone "$(get_repo_url edge_node_api)" "$EDGE_NODE_API"
        cd $EDGE_NODE_API
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > $EDGE_NODE_API/.env
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

        rm -rf node_modules package-lock.json
        npm cache clean --force
        # Install dependencies
        nvm exec 20.18.2 npm install

        # Setup database
        npx sequelize-cli db:migrate
    fi

    cat <<EOL > /etc/systemd/system/edge-node-api.service
[Unit]
Description=Edge Node API Service
After=network.target

[Service]
ExecStart=$HOME/.nvm/versions/node/v22.9.0/bin/node $EDGE_NODE_API/app.js
WorkingDirectory=$EDGE_NODE_API/
EnvironmentFile=$EDGE_NODE_API/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    if [[ "${DEPLOYMENT_MODE,,}" = "production" ]]; then
        systemctl daemon-reload
        systemctl enable edge-node-api
        systemctl start edge-node-api
    fi
}

setup_edge_node_ui() {
    echo "Setting up Edge Node UI..."

    if check_folder "$EDGE_NODE_UI"; then
        git clone "$(get_repo_url edge_node_interface)" "$EDGE_NODE_UI"

        cd $EDGE_NODE_UI
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > $EDGE_NODE_UI/.env
VITE_APP_URL="http://$SERVER_IP"
VITE_APP_NAME="Edge Node"
VITE_AUTH_ENABLED=true
VITE_AUTH_SERVICE_ENDPOINT=http://$SERVER_IP:3001
VITE_EDGE_NODE_BACKEND_ENDPOINT=http://$SERVER_IP:3002
VITE_CHATDKG_API_BASE_URL=http://$SERVER_IP:5002
VITE_APP_ID=edge_node
BASE_URL=http://$SERVER_IP
EOL

        rm -rf node_modules package-lock.json
        npm cache clean --force
        # Build the UI
        nvm exec 22.9.0 npm install
        nvm exec 22.9.0 npm run build

        # Install and configure NGINX
        apt install nginx -y
        systemctl start nginx
        systemctl enable nginx

        # Creating a basic Nginx config for serving the UI on port 80
        NGINX_CONF="/etc/nginx/sites-available/default"
        cp $NGINX_CONF ${NGINX_CONF}.bak

        # Modify the root directive to point to the new directory
        sed -i 's|root /var/www/html;|root /var/www/edge-node-ui/dist;|' $NGINX_CONF
        sed -i 's|try_files $uri $uri/ =404;|try_files $uri $uri/ /index.html =404;|' $NGINX_CONF

        # Enable and restart Nginx with the new configuration
        nginx -t && systemctl restart nginx
    fi
}

setup_drag_api() {
    echo "Setting up dRAG API Service..."

    if check_folder "$DRAG_API"; then
        git clone "$(get_repo_url edge_node_drag)" "$DRAG_API"

        cd $DRAG_API
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > $DRAG_API/.env
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

        rm -rf node_modules package-lock.json
        npm cache clean --force
        # Install dependencies
        nvm exec 22.9.0 npm install

        # Exec migrations
        npx sequelize-cli db:migrate
    fi

    cat <<EOL > /etc/systemd/system/drag-api.service
[Unit]
Description=dRAG API Service
After=network.target

[Service]
ExecStart=$HOME/.nvm/versions/node/v22.9.0/bin/node $DRAG_API/server.js
WorkingDirectory=$DRAG_API
EnvironmentFile=$DRAG_API/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    if [[ "${DEPLOYMENT_MODE,,}" = "production" ]]; then
        systemctl daemon-reload
        systemctl enable drag-api
        systemctl start drag-api
    fi
}


setup_ka_mining_api() {
    echo "Setting up KA Mining API Service..."

    if check_folder "$KA_MINING_API"; then
        git clone "$(get_repo_url edge_node_knowledge_mining)" "$KA_MINING_API"

        cd $KA_MINING_API
        git checkout main

        python3.11 -m venv .venv
        source .venv/bin/activate
        pip install -r requirements.txt

        # Create the .env file with required variables
        cat <<EOL > $KA_MINING_API/.env
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

    cat <<EOL > /etc/systemd/system/ka-mining-api.service
[Unit]
Description=KA Mining API Service
After=network.target

[Service]
ExecStart=$KA_MINING_API/.venv/bin/python $KA_MINING_API/app.py
WorkingDirectory=$KA_MINING_API
EnvironmentFile=$KA_MINING_API/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    if [[ "${DEPLOYMENT_MODE,,}" = "production" ]]; then
        systemctl daemon-reload
        systemctl enable ka-mining-api
        systemctl start ka-mining-api
    fi
}


setup_airflow_service() {
    echo "Setting up Airflow Service..."

    export AIRFLOW_HOME="$EDGE_NODE_DIR/airflow"

    cd $KA_MINING_API

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
    sed -i \
        -e 's|^dags_folder *=.*|dags_folder = '${KA_MINING_API}'/dags|' \
        -e 's|^parallelism *=.*|parallelism = 32|' \
        -e 's|^max_active_tasks_per_dag *=.*|max_active_tasks_per_dag = 16|' \
        -e 's|^max_active_runs_per_dag *=.*|max_active_runs_per_dag = 16|' \
        -e 's|^enable_xcom_pickling *=.*|enable_xcom_pickling = True|' \
        -e 's|^load_examples *=.*|load_examples = False|' \
        $AIRFLOW_HOME/airflow.cfg

    # AIRFLOW WEBSERVER sytemctl setup
    cat <<EOL > /etc/systemd/system/airflow-webserver.service
[Unit]
Description=Airflow Webserver
After=network.target

[Service]
ExecStart=$KA_MINING_API/.venv/bin/airflow webserver --port 8008
WorkingDirectory=$KA_MINING_API
EnvironmentFile=$KA_MINING_API/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    cat <<EOL > /etc/systemd/system/airflow-scheduler.service
[Unit]
Description=Airflow Scheduler
After=network.target

[Service]
ExecStart=$KA_MINING_API/.venv/bin/airflow scheduler
WorkingDirectory=$KA_MINING_API
Environment="PATH=$KA_MINING_API/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    if [[ "${DEPLOYMENT_MODE,,}" = "production" ]]; then
        # Unpause DAGS
        for dag_file in dags/*.py; do
            dag_name=$(basename "$dag_file" .py)
            $KA_MINING_API/.venv/bin/airflow dags unpause "$dag_name"
        done

        systemctl daemon-reload
        systemctl enable airflow-webserver
        systemctl start airflow-webserver
        systemctl enable airflow-scheduler
        systemctl start airflow-scheduler
    fi
}

finish_install() {
    echo "======== RESTARTING SERVICES ==========="
    sleep 10
    systemctl is-enabled otnode.service
    systemctl is-enabled ka-mining-api
    systemctl is-enabled airflow-scheduler
    systemctl is-enabled airflow-webserver
    systemctl is-enabled edge-node-api
    systemctl is-enabled auth-service

    systemctl restart otnode.service
    systemctl restart ka-mining-api
    systemctl restart airflow-scheduler
    systemctl restart airflow-webserver
    systemctl restart edge-node-api
    systemctl restart auth-service

    # ------- CHECK STATUSES OF ALL SERVICES -------
    systemctl status auth-service.service --no-pager || true
    systemctl status ka-mining-api.service --no-pager || true
    systemctl status airflow-webserver --no-pager || true
    systemctl status airflow-scheduler --no-pager || true
    systemctl status drag-api.service --no-pager || true
    systemctl status otnode --no-pager || true

    echo "alias edge-node-restart='systemctl restart auth-service && systemctl restart edge-node-api && systemctl restart ka-mining-api && systemctl restart airflow-scheduler && systemctl restart drag-api'" >> ~/.bashrc
    source ~/.bashrc
}

#!/bin/sh

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


echo "alias edge-node-restart='systemctl restart auth-service && systemctl restart edge-node-api && systemctl restart ka-mining-api && systemctl restart airflow-scheduler && systemctl restart drag-api'" >> ~/.bashrc


install_blazegraph() {
    wget -P $OTNODE_DIR https://github.com/blazegraph/database/releases/latest/download/blazegraph.jar
    cp $OTNODE_DIR/current/installer/data/blazegraph.service /lib/systemd/system/

    systemctl daemon-reload
    systemctl enable blazegraph.service
    systemctl start blazegraph.service
    systemctl status blazegraph.service --no-pager || true

    echo "✅ Blazegraph checked. Continuing execution..."
}



install_mysql() {
    apt install tcllib mysql-server -y
    mysql -u root -p"root" -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';"
    mysql -u root -e "CREATE DATABASE operationaldb /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -u root -e "CREATE DATABASE \`edge-node-auth-service\`"
    mysql -u root -e "CREATE DATABASE \`edge-node-api\`;"
    mysql -u root -e "CREATE DATABASE drag_logging;"
    mysql -u root -e "CREATE DATABASE ka_mining_api_logging;"
    mysql -u root -e "CREATE DATABASE airflow_db;"
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';"
    mysql -u root -p"$DB_PASSWORD" -e "flush privileges;"
    sed -i 's|max_binlog_size|#max_binlog_size|' /etc/mysql/mysql.conf.d/mysqld.cnf
    echo "disable_log_bin"
    echo -e "disable_log_bin\nwait_timeout = 31536000\ninteractive_timeout = 31536000" >> /etc/mysql/mysql.conf.d/mysqld.cnf
    echo "REPOSITORY_PASSWORD=otnodedb" >> /root/ot-node/current/.env
    echo "NODE_ENV=testnet" >> /root/ot-node/current/.env
    cd /root/ot-node/current
    npm ci --omit=dev --ignore-scripts

    systemctl daemon-reload
    systemctl enable mysql.service
    systemctl start mysql.service
    systemctl status mysql.service --no-pager || true
}

install_ot_node() {
    # Setting up node directory:s
    ARCHIVE_REPOSITORY_URL="github.com/OriginTrail/ot-node/archive"
    BRANCH="v6/release/testnet"
    BRANCH_DIR="/root/ot-node-6-release-testnet"
    cd /root
    wget https://$ARCHIVE_REPOSITORY_URL/$BRANCH.zip
    unzip *.zip
    rm *.zip
    OTNODE_VERSION=$(jq -r '.version' $BRANCH_DIR/package.json)
    mkdir $OTNODE_DIR
    mkdir $OTNODE_DIR/$OTNODE_VERSION
    mv $BRANCH_DIR/* $OTNODE_DIR/$OTNODE_VERSION/
    OUTPUT=$(mv $BRANCH_DIR/.* $OTNODE_DIR/$OTNODE_VERSION/ 2>&1)
    rm -rf $BRANCH_DIR
    ln -sfn $OTNODE_DIR/$OTNODE_VERSION $OTNODE_DIR/current

    # Ensure the directory exists
    mkdir -p "$OTNODE_DIR"

    cd /root/edge-node-installer
    # Call the function to generate config
    generate_engine_node_config "$OTNODE_DIR"
    if [[ $? -eq 0 ]]; then
        echo "✅ Blockchain config successfully generated at $OTNODE_DIR"
    else
        echo "❌ Blockchain config generation failed!"
    fi
    chmod 600 /root/ot-node/.origintrail_noderc
    cp /root/ot-node/current/installer/data/otnode.service /lib/systemd/system/

    systemctl enable otnode || true
}


setup() {
    #adding aliases to .bashrc:
    echo "alias otnode-restart='systemctl restart otnode.service'" >> ~/.bashrc
    echo "alias otnode-stop='systemctl stop otnode.service'" >> ~/.bashrc
    echo "alias otnode-start='systemctl start otnode.service'" >> ~/.bashrc
    echo "alias otnode-logs='journalctl -u otnode --output cat -f'" >> ~/.bashrc
    echo "alias otnode-config='nano ~/ot-node/.origintrail_noderc'" >> ~/.bashrc

    # Inside linux.sh, we do an

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

    # Install nodejs v20.18.0 (via NVM).
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash > /dev/null 2>&1
    export NVM_DIR="$HOME/.nvm"

    # This loads nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # This loads nvm bash_completion
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    nvm install 22.9.0 > /dev/null 2>&1
    nvm install 20.18.2 > /dev/null 2>&1

    nvm use 20.18.2 > /dev/null 2>&1
     # Set nodejs v20.18.0 as default and link node to /usr/bin/
    nvm alias default 20.18.2 > /dev/null 2>&1
   
    ln -s $(which node) /usr/bin/ > /dev/null 2>&1
    ln -s $(which npm) /usr/bin/ > /dev/null 2>&1

    install_python
    install_ot_node
    install_blazegraph
    install_mysql
}


setup_auth_service() {
    echo "Setting up Authentication Service..."
    if check_folder "/root/edge-node-auth-service"; then
        git clone "${repos[edge_node_auth_service]}" /root/edge-node-auth-service
        cd /root/edge-node-auth-service
        git checkout main

        # Create the .env file with required variables
        create_env_file
        cat <<EOL > /root/edge-node-auth-service/.env
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

        SQL_FILE="/root/edge-node-auth-service/UserConfig.sql"
        TEMP_SQL_FILE="/root/edge-node-auth-service/UserConfig_temp.sql"

        # Replace 'localhost' with SERVER_IP in SQL file
        sed "s/localhost/$SERVER_IP/g" "$SQL_FILE" > "$TEMP_SQL_FILE"

        # Execute SQL file on MySQL database
        mysql -u "root" -p"$DB_PASSWORD" "edge-node-auth-service" < "$TEMP_SQL_FILE"

        # Clean up temp file
        rm "$TEMP_SQL_FILE"

        echo "User config updated successfully."
    fi;

    cat <<EOL > /etc/systemd/system/auth-service.service
[Unit]
Description=Edge Node Authentication Service
After=network.target

[Service]
ExecStart=/root/.nvm/versions/node/v22.9.0/bin/node /root/edge-node-auth-service/index.js
WorkingDirectory=/root/edge-node-auth-service
EnvironmentFile=/root/edge-node-auth-service/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    systemctl enable auth-service
    systemctl start auth-service
}


setup_edge_node_api() {
    echo "Setting up API Service..."
    if check_folder "/root/edge-node-api"; then
        git clone "${repos[edge_node_api]}" /root/edge-node-api
        cd /root/edge-node-api
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > /root/edge-node-api/.env
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

    cat <<EOL > /etc/systemd/system/edge-node-api.service
[Unit]
Description=Edge Node API Service
After=network.target

[Service]
ExecStart=/root/.nvm/versions/node/v22.9.0/bin/node /root/edge-node-api/app.js
WorkingDirectory=/root/edge-node-api/
EnvironmentFile=/root/edge-node-api/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    systemctl enable edge-node-api.service
    systemctl start edge-node-api.service
}

setup_edge_node_ui() {
    echo "Setting up Edge Node UI..."

    if check_folder "/var/www/edge-node-ui"; then
        git clone "${repos[edge_node_interface]}" /var/www/edge-node-ui
        cd /var/www/edge-node-ui
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > /var/www/edge-node-ui/.env
VITE_APP_URL="http://$SERVER_IP"
VITE_APP_NAME="Edge Node"
VITE_AUTH_ENABLED=true
VITE_AUTH_SERVICE_ENDPOINT=http://$SERVER_IP:3001
VITE_EDGE_NODE_BACKEND_ENDPOINT=http://$SERVER_IP:3002
VITE_CHATDKG_API_BASE_URL=http://$SERVER_IP:5002
VITE_APP_ID=edge_node
BASE_URL=http://$SERVER_IP
EOL

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

    if check_folder "/root/drag-api"; then
        git clone "${repos[edge_node_drag]}" /root/drag-api
        cd /root/drag-api
        git checkout main

        # Create the .env file with required variables
        cat <<EOL > /root/drag-api/.env
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

    cat <<EOL > /etc/systemd/system/drag-api.service
[Unit]
Description=dRAG API Service
After=network.target

[Service]
ExecStart=/root/.nvm/versions/node/v22.9.0/bin/node /root/drag-api/server.js
WorkingDirectory=/root/drag-api
EnvironmentFile=/root/drag-api/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL
    
    systemctl enable drag-api
    systemctl start drag-api
}


setup_ka_minging_api() {
    echo "Setting up KA Mining API Service..."

    if check_folder "/root/ka-mining-api"; then
        git clone "${repos[edge_node_knowledge_mining]}" /root/ka-mining-api
        cd /root/ka-mining-api
        git checkout main

        python3.11 -m venv .venv
        source .venv/bin/activate
        pip install -r requirements.txt

        # Create the .env file with required variables
        cat <<EOL > /root/ka-mining-api/.env
PORT=5005
PYTHON_ENV="STAGING"
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_HOST="127.0.0.1"
DB_NAME="ka_mining_api_logging"
DAG_FOLDER_NAME="/root/ka-mining-api/dags"
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
ExecStart=/root/ka-mining-api/.venv/bin/python /root/ka-mining-api/app.py
WorkingDirectory=/root/ka-mining-api
EnvironmentFile=/root/ka-mining-api/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    systemctl enable ka-mining-api
    systemctl start ka-mining-api
}


setup_airflow_service() {
    echo "Setting up Airflow Service..."

    cd /root/ka-mining-api/

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
        -e 's|^dags_folder *=.*|dags_folder = /root/ka-mining-api/dags|' \
        -e 's|^parallelism *=.*|parallelism = 32|' \
        -e 's|^max_active_tasks_per_dag *=.*|max_active_tasks_per_dag = 16|' \
        -e 's|^max_active_runs_per_dag *=.*|max_active_runs_per_dag = 16|' \
        -e 's|^enable_xcom_pickling *=.*|enable_xcom_pickling = True|' \
        -e 's|^load_examples *=.*|load_examples = False|' \
        /root/airflow/airflow.cfg

    # AIRFLOW WEBSERVER sytemctl setup
    cat <<EOL > /etc/systemd/system/airflow-webserver.service
[Unit]
Description=Airflow Webserver
After=network.target

[Service]
ExecStart=/root/ka-mining-api/.venv/bin/airflow webserver --port 8008
WorkingDirectory=/root/ka-mining-api
EnvironmentFile=/root/ka-mining-api/.env
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    # Unpause DAGS
    for dag_file in dags/*.py; do
        dag_name=$(basename "$dag_file" .py)
        /root/ka-mining-api/.venv/bin/airflow dags unpause "$dag_name"
    done

    # Enable and start the service
    systemctl enable airflow-webserver
    systemctl start airflow-webserver

    cat <<EOL > /etc/systemd/system/airflow-scheduler.service
[Unit]
Description=Airflow Scheduler
After=network.target

[Service]
ExecStart=/root/ka-mining-api/.venv/bin/airflow scheduler
WorkingDirectory=/root/ka-mining-api
Environment="PATH=/root/ka-mining-api/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

    systemctl enable airflow-scheduler
    systemctl start airflow-scheduler
}

check_service_status() {
    # ------- CHECK STATUSES OF ALL SERVICES -------
    systemctl status auth-service.service --no-pager || true
    systemctl status ka-mining-api.service --no-pager || true
    systemctl status airflow-webserver --no-pager || true
    systemctl status airflow-scheduler --no-pager || true
    systemctl status drag-api.service --no-pager || true
    systemctl status otnode --no-pager || true
    source ~/.bashrc
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
}





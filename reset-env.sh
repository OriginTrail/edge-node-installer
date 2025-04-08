#!/usr/bin/env bash

EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"
EDGE_NODE_INSTALLER_DIR=$(pwd)

if [ -f .env ]; then
  source .env
else
  echo "Config file not found. Make sure you have configured your .env file!"
  exit 1
fi

source ./common.sh

rm -rf $EDGE_NODE_DIR

mysql -u root -potnodedb -e "DROP DATABASE drag_logging;"
mysql -u root -potnodedb -e "DROP DATABASE operationaldb;"
mysql -u root -potnodedb -e "DROP DATABASE \`edge-node-auth-service\`;"
mysql -u root -potnodedb -e "DROP DATABASE \`edge-node-api\`;"
mysql -u root -potnodedb -e "DROP DATABASE ka_mining_api_logging;"
mysql -u root -potnodedb -e "DROP DATABASE airflow_db;"


OS=$(uname -s)
if [ "$OS" == "Linux" ]; then
    systemctl stop otnode.service && systemctl disable otnode.service
    systemctl stop ka-mining-api && systemctl disable ka-mining-api
    systemctl stop airflow-scheduler && systemctl disable airflow-scheduler
    systemctl stop airflow-webserver && systemctl disable airflow-webserver
    systemctl stop drag-api && systemctl disable drag-api
    systemctl stop nginx && systemctl disable nginx

    rm -rf /etc/systemd/system/ot-node.service
    rm -rf /etc/systemd/system/ka-mining-api.service
    rm -rf /etc/systemd/system/airflow-scheduler.service
    rm -rf service/etc/systemd/system/airflow-webserver.
    rm -rf /etc/systemd/system/drag-api.service
    rm -rf /etc/systemd/system/nginx.service

    systemctl daemon-reload
fi

pkill -f blazegraph.jar
pkill -f index.js
pkill -f server.js
pkill -f app.js
pkill -f airflow
pkill -f python


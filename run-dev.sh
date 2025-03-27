#!/bin/bash

EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"


java -jar "$OTNODE_DIR/blazegraph/blazegraph.jar" &
$HOME/.nvm/versions/node/v20.18.2/bin/node $OTNODE_DIR/current/index.js &

nvm use 22.9.0 > /dev/null 2>&1

node $EDGE_NODE_DIR/drag-api/server.js &
node $EDGE_NODE_DIR/edge-node-auth-service/index.js &
node $EDGE_NODE_DIR/edge-node-api/app.js &
node $EDGE_NODE_DIR/edge-node-auth-service/index.js &
$EDGE_NODE_DIR/ka-mining-api/.venv/bin/python $EDGE_NODE_DIR/ka-mining-api/app.py &
$EDGE_NODE_DIR/ka-mining-api/.venv/bin/airflow webserver --port 8008 &


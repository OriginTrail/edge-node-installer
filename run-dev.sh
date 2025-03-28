#!/usr/bin/env bash

EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"

pkill -f blazegraph.jar
pkill -f index.js
pkill -f server.js
pkill -f app.js
pkill -f airflow
pkill -f python

export NVM_DIR="$HOME/.nvm"
echo source "$NVM_DIR/nvm.sh" >> "$HOME/.bashrc"
echo source "$NVM_DIR/bash_completion" >> "$HOME/.bashrc"

# java -jar "$OTNODE_DIR/blazegraph/blazegraph.jar" &
# $HOME/.nvm/versions/node/v20.18.2/bin/node $OTNODE_DIR/current/index.js &

nvm use 22.9.0

# node $EDGE_NODE_DIR/drag-api/server.js &
node $EDGE_NODE_DIR/edge-node-auth-service/index.js &
# node $EDGE_NODE_DIR/edge-node-api/app.js &
# node $EDGE_NODE_DIR/edge-node-auth-service/index.js &


# yes | $EDGE_NODE_DIR/ka-mining-api/.venv/bin/airflow webserver --port 8008 &

# # Wait until Airflow is ready
# echo "Waiting for Airflow to start..."
# until curl -s http://localhost:8008/health | grep -q "healthy"; do
#   echo "waiting"
#   sleep 2
# done
# echo "Airflow started successfully!"

# $EDGE_NODE_DIR/ka-mining-api/.venv/bin/python $EDGE_NODE_DIR/ka-mining-api/app.py &
# echo "Python app started!"



#!/usr/bin/env bash

EDGE_NODE_DIR="$HOME/edge_node"
OTNODE_DIR="$EDGE_NODE_DIR/ot-node"

AUTH_SERVICE=$EDGE_NODE_DIR/edge-node-auth-service/
API=$EDGE_NODE_DIR/edge-node-api/
DRAG_API=$EDGE_NODE_DIR/drag-api/
KA_MINING_API=$EDGE_NODE_DIR/ka-mining-api/

pkill -f blazegraph.jar
pkill -f index.js
pkill -f server.js
pkill -f app.js
pkill -f airflow
pkill -f python

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

java -jar "$OTNODE_DIR/blazegraph/blazegraph.jar" &
$HOME/.nvm/versions/node/v20.18.2/bin/node $OTNODE_DIR/current/index.js &

nvm use 22.9.0

cd $DRAG_API && node $EDGE_NODE_DIR/drag-api/server.js &
cd $AUTH_SERVICE && node index.js &
cd $API && node app.js &
yes | $EDGE_NODE_DIR/ka-mining-api/.venv/bin/airflow webserver --port 8008 &

# Wait until Airflow is ready
echo "Waiting for Airflow to start..."
until curl -s http://localhost:8008/health | grep -q "healthy"; do
  echo "waiting"
  sleep 2
done

$KA_MINING_API/.venv/bin/python $EDGE_NODE_DIR/ka-mining-api/app.py &




# configure edge-node components github repositories
repos_keys=("edge_node_knowledge_mining" "edge_node_auth_service" "edge_node_drag" "edge_node_api" "edge_node_interface")
repos_values=(
  "${EDGE_NODE_KNOWLEDGE_MINING_REPO:-https://github.com/OriginTrail/edge-node-knowledge-mining}"
  "${EDGE_NODE_AUTH_SERVICE_REPO:-https://github.com/OriginTrail/edge-node-authentication-service}"
  "${EDGE_NODE_DRAG_REPO:-https://github.com/OriginTrail/edge-node-drag}"
  "${EDGE_NODE_API_REPO:-https://github.com/OriginTrail/edge-node-api}"
  "${EDGE_NODE_UI_REPO:-https://github.com/OriginTrail/edge-node-interface}"
)

# Function to get the repo URL by key
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

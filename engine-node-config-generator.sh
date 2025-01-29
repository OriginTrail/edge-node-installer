#!/bin/bash

generate_engine_node_config() {
    # Get the output directory from argument
    OUTPUT_DIR="$1"

    # Validate output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        echo "Error: No output directory provided!"
        return 1
    fi

    JSON_FILE="$OUTPUT_DIR/.origintrail_noderc"
    TEMP_FILE="$OUTPUT_DIR/temp.json"

    # Ensure output directory exists
    mkdir -p "$OUTPUT_DIR"

    # Ensure jq is installed
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is not installed. Please install jq first."
        return 1
    fi

    # Load environment variables
    if [ -f .env ]; then
        source .env
    else
        echo "Error: .env file not found!"
        return 1
    fi

    # **Ensure JSON_FILE exists or create a default one**
    if [[ ! -f "$JSON_FILE" ]]; then
        echo "{}" > "$JSON_FILE"  # Create an empty JSON structure
        echo "🆕 Created new JSON file at: $JSON_FILE"
    fi

    # Define blockchain ID arrays
    MAINNET_BLOCKCHAIN_IDS=()
    TESTNET_BLOCKCHAIN_IDS=()

    # Define RPC endpoints as JSON objects
    MAINNET_RPCS=$(jq -n '{
      "otp:2043": ["https://astrosat-parachain-rpc.origin-trail.network", "https://astrosat.origintrail.network", "https://astrosat-2.origintrail.network"]
    }')
    TESTNET_RPCS=$(jq -n '{
      "otp:20430": ["https://lofar-testnet.origin-trail.network", "https://lofar-testnet.origintrail.network"]
    }')

    # **Enable or Disable Blockchains Based on .env**
    [[ -n "$NEUROWEB_NODE_NAME" && -n "$NEUROWEB_OPERATOR_FEE" ]] && NEURO_ENABLED=true || NEURO_ENABLED=false
    [[ -n "$BASE_NODE_NAME" && -n "$BASE_OPERATOR_FEE" ]] && BASE_ENABLED=true || BASE_ENABLED=false
    [[ -n "$GNOSIS_NODE_NAME" && -n "$GNOSIS_OPERATOR_FEE" ]] && GNOSIS_ENABLED=true || GNOSIS_ENABLED=false

    # **Set Active Blockchains and RPC Sources Based on Environment**
    ACTIVE_BLOCKCHAINS=()
    if [[ "$BLOCKCHAIN_ENVIRONMENT" == "mainnet" ]]; then
        [[ "$NEURO_ENABLED" == "true" ]] && ACTIVE_BLOCKCHAINS+=("otp:2043")
        [[ "$GNOSIS_ENABLED" == "true" ]] && ACTIVE_BLOCKCHAINS+=("gnosis:100")
        [[ "$BASE_ENABLED" == "true" ]] && ACTIVE_BLOCKCHAINS+=("base:8453")
        BLOCKCHAINS=$(printf '%s\n' "${ACTIVE_BLOCKCHAINS[@]}" | jq -R . | jq -s .)
        DEFAULT_IMPLEMENTATION="otp:2043"
        RPC_SOURCE="$MAINNET_RPCS"
    elif [[ "$BLOCKCHAIN_ENVIRONMENT" == "testnet" ]]; then
        [[ "$NEURO_ENABLED" == "true" ]] && ACTIVE_BLOCKCHAINS+=("otp:20430")
        [[ "$GNOSIS_ENABLED" == "true" ]] && ACTIVE_BLOCKCHAINS+=("gnosis:10200")
        [[ "$BASE_ENABLED" == "true" ]] && ACTIVE_BLOCKCHAINS+=("base:84532")
        BLOCKCHAINS=$(printf '%s\n' "${ACTIVE_BLOCKCHAINS[@]}" | jq -R . | jq -s .)
        DEFAULT_IMPLEMENTATION="otp:20430"
        RPC_SOURCE="$TESTNET_RPCS"
    else
        echo "Error: BLOCKCHAIN_ENVIRONMENT is not set to 'mainnet' or 'testnet'"
        return 1
    fi

    # **Append Additional RPC Endpoints if Available**
    if [[ -n "$BASE_RPC_ENDPOINT" ]]; then
        RPC_SOURCE=$(echo "$RPC_SOURCE" | jq --arg endpoint "$BASE_RPC_ENDPOINT" --arg chain "base:8453" '.[$chain] += [$endpoint]')
        RPC_SOURCE=$(echo "$RPC_SOURCE" | jq --arg endpoint "$BASE_RPC_ENDPOINT" --arg chain "base:84532" '.[$chain] += [$endpoint]')
    fi
    if [[ -n "$GNOSIS_RPC_ENDPOINT" ]]; then
        RPC_SOURCE=$(echo "$RPC_SOURCE" | jq --arg endpoint "$GNOSIS_RPC_ENDPOINT" --arg chain "gnosis:100" '.[$chain] += [$endpoint]')
        RPC_SOURCE=$(echo "$RPC_SOURCE" | jq --arg endpoint "$GNOSIS_RPC_ENDPOINT" --arg chain "gnosis:10200" '.[$chain] += [$endpoint]')
    fi

    # **Generate `rpcEndpoints` Dynamically for Enabled Blockchains**
    RPC_ENDPOINTS="{}"
    for CHAIN in "${ACTIVE_BLOCKCHAINS[@]}"; do
        RPC_VALUES=$(echo "$RPC_SOURCE" | jq --arg chain "$CHAIN" '.[$chain] // [""]')
        RPC_ENDPOINTS=$(echo "$RPC_ENDPOINTS" | jq --arg chain "$CHAIN" --argjson rpc "$RPC_VALUES" '. + {($chain): $rpc}')
    done

    # **Generate `modules.blockchain.implementation`**
    IMPLEMENTATION="{}"
    for CHAIN in "${ACTIVE_BLOCKCHAINS[@]}"; do
        case "$CHAIN" in
            "otp:2043"|"otp:20430")
                ENABLED=$NEURO_ENABLED
                NODE_NAME="$NEUROWEB_NODE_NAME"
                OPERATOR_FEE="${NEUROWEB_OPERATOR_FEE:-0}"
                MANAGEMENT_WALLET="$NEUROWEB_MANAGEMENT_KEY_PUBLIC_ADDRESS"
                OPERATIONAL_PUBLIC_KEY="$NEUROWEB_OPERATIONAL_KEY_PUBLIC_ADDRESS"
                OPERATIONAL_PRIVATE_KEY="$NEUROWEB_OPERATIONAL_KEY_PRIVATE_ADDRESS"
                ;;
            "gnosis:100"|"gnosis:10200")
                ENABLED=$GNOSIS_ENABLED
                NODE_NAME="$GNOSIS_NODE_NAME"
                OPERATOR_FEE="${GNOSIS_OPERATOR_FEE:-0}"
                MANAGEMENT_WALLET="$GNOSIS_MANAGEMENT_KEY_PUBLIC_ADDRESS"
                OPERATIONAL_PUBLIC_KEY="$GNOSIS_OPERATIONAL_KEY_PUBLIC_ADDRESS"
                OPERATIONAL_PRIVATE_KEY="$GNOSIS_OPERATIONAL_KEY_PRIVATE_ADDRESS"
                ;;
            "base:8453"|"base:84532")
                ENABLED=$BASE_ENABLED
                NODE_NAME="$BASE_NODE_NAME"
                OPERATOR_FEE="${BASE_OPERATOR_FEE:-0}"
                MANAGEMENT_WALLET="$BASE_MANAGEMENT_KEY_PUBLIC_ADDRESS"
                OPERATIONAL_PUBLIC_KEY="$BASE_OPERATIONAL_KEY_PUBLIC_ADDRESS"
                OPERATIONAL_PRIVATE_KEY="$BASE_OPERATIONAL_KEY_PRIVATE_ADDRESS"
                ;;
        esac

        # Ensure OPERATOR_FEE is a valid integer
        if [[ "$OPERATOR_FEE" =~ ^[0-9]+$ ]]; then
            OPERATOR_FEE_INT=$OPERATOR_FEE
        else
            OPERATOR_FEE_INT=0
        fi

        # Fetch RPC endpoints for gnosis/base if available
        RPC_VALUES=$(echo "$RPC_SOURCE" | jq --arg chain "$CHAIN" '.[$chain] // [""]')

        # Create blockchain implementation object with `operatorFee` as an integer
        CHAIN_CONFIG=$(jq -n --arg nodeName "$NODE_NAME" \
                              --argjson operatorFee "$OPERATOR_FEE_INT" \
                              --arg managementWallet "$MANAGEMENT_WALLET" \
                              --arg operationalPublic "$OPERATIONAL_PUBLIC_KEY" \
                              --arg operationalPrivate "$OPERATIONAL_PRIVATE_KEY" \
                              --argjson rpcEndpoints "$RPC_VALUES" \
                              --argjson enabled "$ENABLED" \
            '{
                "config": {
                    "nodeName": $nodeName,
                    "operatorFee": $operatorFee,
                    "evmManagementWalletPublicKey": $managementWallet,
                    "operationalWallets": [{
                        "evmAddress": $operationalPublic,
                        "privateKey": $operationalPrivate
                    }]
                },
                "enabled": $enabled
            }')

        # Append to implementation JSON object
        IMPLEMENTATION=$(echo "$IMPLEMENTATION" | jq --arg chain "$CHAIN" --argjson config "$CHAIN_CONFIG" '. + {($chain): $config}')
    done

    # ✅ Update the JSON file
    jq --argjson implementation "$IMPLEMENTATION" '.modules.blockchain.implementation = $implementation' "$JSON_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$JSON_FILE"
}

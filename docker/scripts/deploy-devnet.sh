#!/bin/bash
# Deploy KeyMarket to local devnet using sncast
set -e

echo "🚀 Deploying KeyMarket to devnet..."

# Check if devnet is running
if ! curl -s http://localhost:5050/is_alive > /dev/null 2>&1; then
    echo "❌ Devnet not running. Start it first:"
    echo "   starknet-devnet --host 0.0.0.0 --port 5050 --seed 12345"
    exit 1
fi

# Build if needed
if [ ! -f target/dev/key_onchain_KeyMarket.compiled_contract_class.json ]; then
    echo "📦 Building contracts..."
    scarb build
fi

# Declare
echo "📝 Declaring contract..."
DECLARE_RESULT=$(sncast declare \
    --url http://localhost:5050 \
    --account-file ~/.starknet_accounts/starknet_openrpc_1.json \
    --contract-path target/dev/key_onchain_KeyMarket.compiled_contract_class.json \
    2>&1)

echo "$DECLARE_RESULT"
CLASS_HASH=$(echo "$DECLARE_RESULT" | grep -oP 'class_hash: \K0x[0-9a-fA-F]+')

if [ -z "$CLASS_HASH" ]; then
    echo "❌ Declare failed"
    exit 1
fi

echo "✅ Class hash: $CLASS_HASH"

# Deploy
echo "📦 Deploying..."
DEPLOY_RESULT=$(sncast deploy \
    --url http://localhost:5050 \
    --account-file ~/.starknet_accounts/starknet_openrpc_1.json \
    --class-hash "$CLASS_HASH" \
    --constructor-calldata 0x127058687166639230431872114492350844249053916038363788110312559 \
    2>&1)

echo "$DEPLOY_RESULT"
CONTRACT_ADDRESS=$(echo "$DEPLOY_RESULT" | grep -oP 'contract_address: \K0x[0-9a-fA-F]+')

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo "❌ Deploy failed"
    exit 1
fi

echo ""
echo "✅ Contract deployed at: $CONTRACT_ADDRESS"
echo ""

# Save to file
echo "{\"contract_address\": \"$CONTRACT_ADDRESS\", \"class_hash\": \"$CLASS_HASH\"}" > deployment.json

echo "📋 Deployment info saved to deployment.json"
echo ""
echo "Add to frontend console:"
echo "  localStorage.setItem('keymarket_address', '$CONTRACT_ADDRESS')"

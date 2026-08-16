#!/bin/bash
# Deploy KeyOnChain contracts to Starknet Sepolia testnet
set -e

echo "🚀 Deploying KeyOnChain to Sepolia Testnet"
echo "==========================================="

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

# Configuration
NETWORK="testnet"
RPC_URL="https://starknet-sepolia.public.blastapi.io/rpc/v0_7"
PRIVATE_KEY="${STARKNET_PRIVATE_KEY:-}"
ACCOUNT_ADDRESS="${STARKNET_ACCOUNT_ADDRESS:-}"

if [ -z "$PRIVATE_KEY" ] || [ -z "$ACCOUNT_ADDRESS" ]; then
    echo "❌ Error: Set STARKNET_PRIVATE_KEY and STARKNET_ACCOUNT_ADDRESS"
    echo ""
    echo "Example:"
    echo "  export STARKNET_PRIVATE_KEY=0x..."
    echo "  export STARKNET_ACCOUNT_ADDRESS=0x..."
    exit 1
fi

echo "📦 Building contracts..."
scarb build

echo ""
echo "📋 Deploying KeyOnChain..."
echo "   Account: $ACCOUNT_ADDRESS"
echo "   Network: $NETWORK"

# Deploy KeyOnChain
# You'll need to replace VENDOR_ADDRESS with the actual vendor address
VENDOR_ADDRESS="${VENDOR_ADDRESS:-$ACCOUNT_ADDRESS}"

echo ""
echo "🔑 Deploying KeyOnChain with vendor: $VENDOR_ADDRESS"

# Using sncast for deployment
sncast --url "$RPC_URL" \
       --account-file ~/.starknet_accounts/starknet_accounts.json \
       deploy \
       --class-hash "$(cat target/dev/key_onchain_KeyOnChain.contract_class_hash.json 2>/dev/null || echo '0x...')"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Verify contract on Starkscan"
echo "   2. Update contract address in config"
echo "   3. Run demo with: bash docker/scripts/demo-sepolia.sh"

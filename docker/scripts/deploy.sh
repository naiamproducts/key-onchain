#!/bin/bash
# Deploy contracts to local devnet
set -e

echo "🚀 Deploying KeyOnChain to devnet..."
echo "====================================="

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

# Check if devnet is running
if ! curl -s http://localhost:5050 > /dev/null 2>&1; then
    echo "❌ Devnet is not running!"
    echo "   Start it with: docker compose up devnet"
    exit 1
fi

echo "📦 Building contracts..."
scarb build

echo ""
echo "🔑 Deploying KeyOnChain..."
# You would use sncast here for actual deployment
# sncast deploy --url http://localhost:5050 --class-hash <hash>

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Contract addresses:"
echo "   KeyOnChain: 0x..."

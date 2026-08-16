#!/bin/bash
# Run all tests
set -e

echo "🧪 Running KeyOnChain tests..."
echo "================================"

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

echo "📦 Building contracts..."
scarb build

echo ""
echo "🧪 Running snforge tests..."
snforge test

echo ""
echo "✅ All tests passed!"

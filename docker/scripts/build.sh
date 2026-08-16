#!/bin/bash
# Build all contracts
set -e

echo "🔨 Building KeyOnChain contracts..."
echo "===================================="

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

echo "📦 Compiling..."
scarb build

echo ""
echo "📋 Build artifacts:"
ls -la target/dev/*.sierra 2>/dev/null || echo "  No Sierra artifacts"
ls -la target/dev/*.casm 2>/dev/null || echo "  No CASM artifacts"

echo ""
echo "✅ Build complete!"

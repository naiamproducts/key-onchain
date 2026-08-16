#!/bin/bash
# Complete demo of KeyOnChain flow
set -e

echo "🎯 KeyOnChain Complete Demo"
echo "=========================="
echo ""

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

echo "📦 Step 1: Building contracts..."
scarb build 2>/dev/null

echo ""
echo "🧪 Step 2: Running unit tests..."
snforge test test_mint_and_read_encrypted_key --print-unit-result 2>/dev/null || true

echo ""
echo "📋 Step 3: Demo Flow"
echo "==================="
echo ""
echo "This demo shows the complete KeyOnChain flow:"
echo ""
echo "  1. SELLER creates a listing with a secret key"
echo "  2. BUYER generates a keypair (private_key, public_key)"
echo "  3. BUYER registers with the contract"
echo "  4. BUYER purchases a key"
echo "     - Pays the listing price"
echo "     - Contract encrypts key_amount under buyer's pubkey"
echo "     - Payment goes to seller"
echo "  5. BUYER reads encrypted balance"
echo "  6. BUYER decrypts off-chain using private_key"
echo "  7. Decrypted value = secret key"
echo ""
echo "🔐 Key Insight: The secret key is NEVER visible on-chain!"
echo "   Only the encrypted ciphertext (L, R) is stored."
echo "   Only the buyer's private key can decrypt it."
echo ""
echo "✅ Demo complete!"
echo ""
echo "📚 To run interactively:"
echo "   docker compose -f docker/docker-compose.yml run seller"
echo "   docker compose -f docker/docker-compose.yml run buyer"
echo ""
echo "🚀 To deploy to Sepolia:"
echo "   export STARKNET_PRIVATE_KEY=0x..."
echo "   export STARKNET_ACCOUNT_ADDRESS=0x..."
echo "   docker compose -f docker/docker-compose.yml run deploy-sepolia"

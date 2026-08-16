#!/bin/bash
# Interactive demo of KeyOnChain
set -e

echo "🎯 KeyOnChain Interactive Demo"
echo "=============================="
echo ""
echo "This script demonstrates the KeyOnChain flow:"
echo "  1. Vendor generates a keypair for buyer"
echo "  2. Vendor encrypts a secret key under buyer's public key"
echo "  3. Encrypted balance is stored on-chain"
echo "  4. Buyer decrypts off-chain to recover the secret key"
echo ""

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

echo "📦 Building contracts..."
scarb build 2>/dev/null

echo ""
echo "🧪 Running demo test..."
snforge test test_mint_and_read_encrypted_key -vvv 2>/dev/null || \
    snforge test test_mint_and_read_encrypted_key --print-unit-result

echo ""
echo "✅ Demo complete!"
echo ""
echo "📚 Key concepts:"
echo "   - ElGamal encryption hides the key amount on-chain"
echo "   - Only the buyer's private key can decrypt the balance"
echo "   - The encrypted balance (L, R) is publicly visible but unintelligible"
echo "   - This enables 'amount as key' distribution without revealing the key"

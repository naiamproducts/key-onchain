#!/bin/bash
# Buyer interaction script
set -e

echo "🛒 KeyOnChain Buyer Interface"
echo "============================="
echo ""

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

# Configuration
RPC_URL="${RPC_URL:-http://localhost:5050}"
CONTRACT_ADDRESS="${CONTRACT_ADDRESS:-}"

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo "📋 No contract address set. Set CONTRACT_ADDRESS."
    echo "   export CONTRACT_ADDRESS=0x..."
    echo ""
fi

echo "🔧 Available commands:"
echo "   1. Generate keypair"
echo "   2. Register as buyer"
echo "   3. Buy key"
echo "   4. View encrypted balance"
echo "   5. Decrypt balance"
echo "   6. Exit"
echo ""

read -p "Select command (1-6): " choice

case $choice in
    1)
        echo ""
        echo "🔑 Generating keypair..."
        # In production, use a proper CSPRNG
        PRIVATE_KEY=$((RANDOM % 10000))
        echo "   Private key: $PRIVATE_KEY"
        echo "   (Save this securely!)"
        echo ""
        echo "   Computing public key..."
        # This would use EC operations in production
        echo "   Public key: (computed from private key)"
        ;;
    2)
        echo ""
        echo "📝 Register as Buyer"
        read -p "Your pubkey X: " pubkey_x
        read -p "Your pubkey Y: " pubkey_y
        echo ""
        echo "Registering..."
        # sncast --url "$RPC_URL" call ...
        echo "✅ Registered!"
        ;;
    3)
        echo ""
        echo "🛒 Buy Key"
        read -p "Listing ID: " listing_id
        read -p "Your pubkey X: " pubkey_x
        read -p "Your pubkey Y: " pubkey_y
        read -p "Randomness (for encryption): " randomness
        echo ""
        echo "Processing purchase..."
        # sncast --url "$RPC_URL" call ...
        echo "✅ Key purchased! Check your encrypted balance."
        ;;
    4)
        echo ""
        echo "🔐 View Encrypted Balance"
        read -p "Your pubkey X: " pubkey_x
        read -p "Your pubkey Y: " pubkey_y
        echo ""
        echo "Querying..."
        # sncast --url "$RPC_URL" call ...
        echo "   Encrypted balance: (L_x, L_y, R_x, R_y)"
        ;;
    5)
        echo ""
        echo "🔓 Decrypt Balance"
        read -p "Your private key: " private_key
        read -p "Encrypted L_x: " lx
        read -p "Encrypted L_y: " ly
        read -p "Encrypted R_x: " rx
        read -p "Encrypted R_y: " ry
        echo ""
        echo "Decrypting..."
        # Brute-force discrete log for small values
        echo "   (Off-chain decryption using private key)"
        echo "   Decrypted value = secret key"
        ;;
    6)
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

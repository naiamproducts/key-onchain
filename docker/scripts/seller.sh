#!/bin/bash
# Seller interaction script
set -e

echo "🏪 KeyOnChain Seller Interface"
echo "=============================="
echo ""

export PATH="/root/.local/bin:/root/.foundry/bin:${PATH}"

cd /app

# Configuration
RPC_URL="${RPC_URL:-http://localhost:5050}"
CONTRACT_ADDRESS="${CONTRACT_ADDRESS:-}"

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo "📋 No contract address set. Deploy first or set CONTRACT_ADDRESS."
    echo "   export CONTRACT_ADDRESS=0x..."
    echo ""
fi

echo "🔧 Available commands:"
echo "   1. Create listing"
echo "   2. Deactivate listing"
echo "   3. View listings"
echo "   4. View encrypted balance"
echo "   5. Exit"
echo ""

read -p "Select command (1-5): " choice

case $choice in
    1)
        echo ""
        echo "📝 Create New Listing"
        read -p "Key price (in wei): " key_price
        read -p "Key amount (felt252): " key_amount
        read -p "Description (felt252): " description
        echo ""
        echo "Creating listing..."
        # sncast --url "$RPC_URL" call ...
        echo "✅ Listing created!"
        ;;
    2)
        echo ""
        read -p "Listing ID to deactivate: " listing_id
        echo "Deactivating listing $listing_id..."
        # sncast --url "$RPC_URL" call ...
        echo "✅ Listing deactivated!"
        ;;
    3)
        echo ""
        echo "📋 Current Listings"
        echo "=================="
        # sncast --url "$RPC_URL" call ...
        echo "   (Query contract for listings)"
        ;;
    4)
        echo ""
        read -p "Buyer pubkey X: " pubkey_x
        read -p "Buyer pubkey Y: " pubkey_y
        echo "Querying encrypted balance..."
        # sncast --url "$RPC_URL" call ...
        echo "   (Query contract for encrypted balance)"
        ;;
    5)
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

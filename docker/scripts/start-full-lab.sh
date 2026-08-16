#!/bin/bash
# Start full lab: devnet + frontend + cloudflare tunnel
set -e

echo "🚀 KeyOnChain Full Lab"
echo "======================"

export PATH="/home/dev/.local/bin:$PATH"

cd /home/dev/key_onchain

# Start devnet in background
echo "📦 Starting Starknet Devnet..."
starknet-devnet --host 0.0.0.0 --port 5050 --seed 12345 &
DEVNET_PID=$!
sleep 3

# Start frontend server
echo "🌐 Starting Frontend Server..."
cd frontend
python3 -m http.server 3000 --bind 0.0.0.0 &
FRONTEND_PID=$!
sleep 2

echo ""
echo "✅ Services running:"
echo "   Devnet:    http://localhost:5050"
echo "   Frontend:  http://localhost:3000"
echo ""
echo "🔗 Starting Cloudflare Tunnel..."
echo "   Copy the URL below and open in browser:"
echo ""

# Start cloudflare tunnel
cloudflared tunnel --url http://localhost:3000

# Cleanup
kill $DEVNET_PID $FRONTEND_PID 2>/dev/null

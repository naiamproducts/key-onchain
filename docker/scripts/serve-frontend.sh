#!/bin/bash
# Serve the KeyOnChain frontend
set -e

echo "🌐 Starting KeyOnChain Frontend Server"
echo "====================================="

cd /home/dev/key_onchain/frontend

PORT="${PORT:-3000}"

echo "📡 Server starting on http://localhost:$PORT"
echo ""
echo "🔗 Cloudflare Tunnel:"
echo "   Run in another terminal:"
echo "   cloudflared tunnel --url http://localhost:$PORT"
echo ""

# Start simple HTTP server
python3 -m http.server $PORT --bind 0.0.0.0

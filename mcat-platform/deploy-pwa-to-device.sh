#!/bin/bash

# MCAT Platform - PWA Deployment Script
# Automatically deploys PWA to your local network for mobile access

set -e

echo "📱 MCAT Platform - PWA Deployment to Mobile Device"
echo "=================================================="
echo ""

# Get local IP address
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
    LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}' 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    LOCAL_IP=$(ipconfig | grep "IPv4" | head -1 | awk '{print $NF}')
else
    echo "⚠️  Could not detect IP automatically"
    read -p "Enter your PC's IP address: " LOCAL_IP
fi

echo "🌐 Detected IP: $LOCAL_IP"
echo ""

# Create .env.local file
echo "📝 Creating frontend-mobile/.env.local..."
cat > frontend-mobile/.env.local << EOF
NEXT_PUBLIC_API_URL=http://${LOCAL_IP}:8001
NEXT_PUBLIC_APP_NAME=MCAT Platform
EOF

echo "✅ Configuration updated"
echo ""

# Check if Docker is running
echo "🐳 Checking Docker services..."
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Start backend services
echo "🚀 Starting backend services (Postgres, Redis, FastAPI)..."
docker compose up -d postgres redis

# Wait for Postgres
echo "⏳ Waiting for Postgres to be ready..."
for i in {1..30}; do
    if docker exec mcat_postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ Postgres is ready"
        break
    fi
    sleep 1
done

# Start mobile API
echo "🚀 Starting mobile API (port 8001)..."
docker compose up -d fastapi_mobile

# Wait for API
echo "⏳ Waiting for API to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8001/health > /dev/null 2>&1; then
        echo "✅ API is ready"
        break
    fi
    sleep 1
done

echo ""
echo "=================================================="
echo "✅ Backend is running!"
echo "=================================================="
echo ""
echo "📱 Now starting frontend..."
echo ""

# Start frontend
cd frontend-mobile

if [ ! -d "node_modules" ]; then
    echo "📦 Installing frontend dependencies..."
    npm install
fi

echo ""
echo "🚀 Starting Next.js development server..."
echo ""
echo "=================================================="
echo "✨ DEPLOYMENT READY!"
echo "=================================================="
echo ""
echo "📱 On your Moto G device:"
echo "   1. Connect to the same WiFi network"
echo "   2. Open Chrome browser"
echo "   3. Go to: http://${LOCAL_IP}:3001"
echo "   4. Tap menu (⋮) → 'Add to Home Screen'"
echo "   5. App installed! 🎉"
echo ""
echo "🔗 URLs:"
echo "   Frontend: http://${LOCAL_IP}:3001"
echo "   API:      http://${LOCAL_IP}:8001"
echo "   Health:   http://${LOCAL_IP}:8001/health"
echo ""
echo "Press Ctrl+C to stop the servers"
echo "=================================================="
echo ""

# Start Next.js with network binding
npm run dev -- -H 0.0.0.0 -p 3001

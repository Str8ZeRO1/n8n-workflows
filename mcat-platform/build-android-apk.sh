#!/bin/bash

# MCAT Platform - Android APK Builder
# Builds native Android APK using Capacitor

set -e

echo "🤖 MCAT Platform - Android APK Builder"
echo "======================================"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install npm first."
    exit 1
fi

echo "✅ Node.js $(node -v)"
echo "✅ npm $(npm -v)"
echo ""

# Get PC IP
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
    LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}' 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    LOCAL_IP=$(ipconfig | grep "IPv4" | head -1 | awk '{print $NF}')
else
    read -p "Enter your PC's IP address: " LOCAL_IP
fi

echo "🌐 Using API URL: http://${LOCAL_IP}:8001"
echo ""

cd frontend-mobile

# Install dependencies
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Install Capacitor
echo "📦 Installing Capacitor..."
npm install @capacitor/core @capacitor/cli @capacitor/android

# Update Next.js config for static export
echo "📝 Updating Next.js config..."
cat > next.config.js << EOF
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  output: 'export',
  images: {
    unoptimized: true,
  },
  env: {
    NEXT_PUBLIC_API_URL: 'http://${LOCAL_IP}:8001',
    NEXT_PUBLIC_APP_NAME: 'MCAT Platform',
  },
}

module.exports = nextConfig
EOF

# Build Next.js
echo "🏗️  Building Next.js app..."
npm run build

# Initialize Capacitor if needed
if [ ! -f "capacitor.config.json" ]; then
    echo "⚙️  Initializing Capacitor..."
    npx cap init "MCAT Platform" com.mcatplatform.app --web-dir=out
fi

# Update Capacitor config
echo "📝 Updating Capacitor config..."
cat > capacitor.config.json << EOF
{
  "appId": "com.mcatplatform.app",
  "appName": "MCAT Platform",
  "webDir": "out",
  "bundledWebRuntime": false,
  "server": {
    "androidScheme": "https",
    "cleartext": true,
    "allowNavigation": ["${LOCAL_IP}:8001"]
  }
}
EOF

# Add Android platform
if [ ! -d "android" ]; then
    echo "📱 Adding Android platform..."
    npx cap add android
else
    echo "📱 Syncing Android platform..."
    npx cap sync
fi

echo ""
echo "======================================"
echo "✅ Android project ready!"
echo "======================================"
echo ""
echo "📦 Next steps:"
echo ""
echo "Option A: Build APK with Gradle (command line)"
echo "   cd android"
echo "   ./gradlew assembleDebug"
echo "   APK: android/app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "Option B: Open in Android Studio"
echo "   npx cap open android"
echo "   Build → Build Bundle(s) / APK(s) → Build APK(s)"
echo ""
echo "Option C: Install via ADB (if device connected)"
echo "   cd android"
echo "   ./gradlew assembleDebug"
echo "   adb install app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "======================================"

#!/bin/bash

# MCAT Platform - ADB APK Installer
# Installs APK to connected Android device via ADB

set -e

echo "📱 MCAT Platform - ADB APK Installer"
echo "===================================="
echo ""

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    echo "❌ ADB not found in PATH"
    echo ""
    echo "Please install Android SDK Platform Tools:"
    echo "  https://developer.android.com/studio/releases/platform-tools"
    echo ""
    echo "Or add to PATH:"
    echo "  Windows: C:\\Users\\YourName\\AppData\\Local\\Android\\Sdk\\platform-tools"
    echo "  macOS: ~/Library/Android/sdk/platform-tools"
    echo "  Linux: ~/Android/Sdk/platform-tools"
    exit 1
fi

echo "✅ ADB found: $(adb version | head -1)"
echo ""

# Check for connected devices
echo "🔍 Checking for connected devices..."
DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)

if [ "$DEVICES" -eq 0 ]; then
    echo "❌ No devices connected"
    echo ""
    echo "📱 Enable USB Debugging on your Moto G:"
    echo "   1. Settings → About Phone"
    echo "   2. Tap 'Build Number' 7 times"
    echo "   3. Settings → Developer Options"
    echo "   4. Enable 'USB Debugging'"
    echo "   5. Connect USB cable"
    echo "   6. Tap 'Always allow' when prompt appears"
    echo ""
    exit 1
fi

echo "✅ Found $DEVICES device(s)"
adb devices
echo ""

# Find APK
APK_PATH="frontend-mobile/android/app/build/outputs/apk/debug/app-debug.apk"

if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found at: $APK_PATH"
    echo ""
    echo "Please build the APK first:"
    echo "   ./build-android-apk.sh"
    echo "   cd frontend-mobile/android"
    echo "   ./gradlew assembleDebug"
    exit 1
fi

echo "✅ Found APK: $APK_PATH"
APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
echo "   Size: $APK_SIZE"
echo ""

# Install APK
echo "📲 Installing APK..."
adb install -r "$APK_PATH"

if [ $? -eq 0 ]; then
    echo ""
    echo "===================================="
    echo "✅ APK installed successfully!"
    echo "===================================="
    echo ""
    echo "📱 Launch app:"
    echo "   adb shell am start -n com.mcatplatform.app/.MainActivity"
    echo ""
    echo "Or tap the 'MCAT Platform' icon on your Moto G"
    echo ""
    echo "🔍 View logs:"
    echo "   adb logcat | grep -i mcat"
    echo ""
    
    # Ask if user wants to launch
    read -p "Launch app now? (y/n): " LAUNCH
    if [ "$LAUNCH" = "y" ] || [ "$LAUNCH" = "Y" ]; then
        echo "🚀 Launching app..."
        adb shell am start -n com.mcatplatform.app/.MainActivity
        echo "✅ App launched!"
    fi
else
    echo ""
    echo "❌ Installation failed"
    echo ""
    echo "Try:"
    echo "   adb uninstall com.mcatplatform.app"
    echo "   adb install $APK_PATH"
fi

# 📱 Deploy MCAT App to Moto G Device

Complete guide to deploy the mobile app to your Moto G device using ADB.

## 🎯 Two Deployment Options

### Option 1: PWA (Fastest - 5 minutes)
Access via browser, install as PWA on home screen

### Option 2: Native APK (Full Native - 15 minutes)
Build and install real Android app using Capacitor + ADB

---

## 🚀 Option 1: PWA Deployment (RECOMMENDED)

### Step 1: Get Your PC's IP Address

**Windows:**
```cmd
ipconfig
```
Look for "IPv4 Address" under your active network adapter (e.g., `192.168.1.100`)

**WSL/Linux:**
```bash
ip addr show | grep inet
```

### Step 2: Update Frontend Config

Edit `frontend-mobile/.env.local`:
```env
NEXT_PUBLIC_API_URL=http://YOUR_PC_IP:8001
NEXT_PUBLIC_APP_NAME=MCAT Platform
```

Replace `YOUR_PC_IP` with your actual IP (e.g., `192.168.1.100`)

### Step 3: Start Backend & Frontend

```bash
cd C:\dev\str8zero-agent-mesh\mcat-platform

# Start backend on port 8001
docker compose up -d postgres redis fastapi_mobile

# Start frontend on port 3001 (accessible on network)
cd frontend-mobile
npm run dev -- -H 0.0.0.0
```

### Step 4: Access on Moto G

1. **Connect Moto G to same WiFi** as your PC
2. **Open Chrome** on Moto G
3. **Go to**: `http://YOUR_PC_IP:3001` (e.g., `http://192.168.1.100:3001`)
4. **You should see the dark-themed login page!**

### Step 5: Install as PWA

1. In Chrome, tap the **⋮** menu
2. Tap **"Add to Home Screen"**
3. Tap **"Add"**
4. App icon appears on home screen with dark theme
5. Opens in standalone mode (no browser UI)

✅ **Done! You now have the app on your Moto G!**

---

## 🤖 Option 2: Native Android APK (Full Deploy)

Build a real Android app and install via ADB.

### Prerequisites

1. **Node.js** installed
2. **Android Studio** installed (or Android SDK)
3. **ADB** in PATH
4. **Capacitor CLI** installed

### Step 1: Install Capacitor

```bash
cd frontend-mobile

# Install Capacitor
npm install @capacitor/core @capacitor/cli
npm install @capacitor/android

# Initialize Capacitor
npx cap init "MCAT Platform" com.mcatplatform.app --web-dir=out
```

### Step 2: Update Next.js Config

Edit `frontend-mobile/next.config.js`:
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  output: 'export',  // Add this for static export
  images: {
    unoptimized: true,  // Add this
  },
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://YOUR_PC_IP:8001',
  },
}

module.exports = nextConfig
```

### Step 3: Build for Production

```bash
# Build Next.js app
npm run build

# This creates 'out/' directory with static files
```

### Step 4: Add Android Platform

```bash
# Add Android platform
npx cap add android

# Copy web assets to native project
npx cap sync

# Open in Android Studio (optional)
npx cap open android
```

### Step 5: Configure Capacitor

Edit `capacitor.config.json`:
```json
{
  "appId": "com.mcatplatform.app",
  "appName": "MCAT Platform",
  "webDir": "out",
  "bundledWebRuntime": false,
  "server": {
    "androidScheme": "https",
    "cleartext": true,
    "allowNavigation": ["YOUR_PC_IP:8001"]
  }
}
```

### Step 6: Build APK

**Option A: Using Gradle (Command Line)**
```bash
cd android
./gradlew assembleDebug
```

APK location: `android/app/build/outputs/apk/debug/app-debug.apk`

**Option B: Using Android Studio**
1. Open `android/` folder in Android Studio
2. Build → Build Bundle(s) / APK(s) → Build APK(s)

### Step 7: Connect Moto G via ADB

```bash
# Enable USB Debugging on Moto G:
# Settings → About Phone → Tap "Build Number" 7 times
# Settings → Developer Options → Enable USB Debugging

# Connect USB cable
# Check device is connected
adb devices

# Expected output:
# List of devices attached
# ABC123DEF456    device
```

### Step 8: Install APK via ADB

```bash
# Navigate to APK location
cd android/app/build/outputs/apk/debug

# Install APK
adb install app-debug.apk

# Or force reinstall if already installed
adb install -r app-debug.apk
```

### Step 9: Launch App

```bash
# Launch app
adb shell am start -n com.mcatplatform.app/.MainActivity

# Or just tap the app icon on your Moto G
```

✅ **Done! Native Android app installed!**

---

## 🔧 ADB Useful Commands

### View Logs
```bash
# View app logs in real-time
adb logcat | grep -i mcat

# Clear logs
adb logcat -c
```

### Uninstall App
```bash
adb uninstall com.mcatplatform.app
```

### Push Files to Device
```bash
# Push APK without installing
adb push app-debug.apk /sdcard/Download/
```

### Screenshot
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

### Device Info
```bash
# Device model
adb shell getprop ro.product.model

# Android version
adb shell getprop ro.build.version.release

# Screen resolution
adb shell wm size

# Battery level
adb shell dumpsys battery
```

---

## 🐛 Troubleshooting

### Issue: "device unauthorized"
**Solution:**
1. Disconnect USB
2. On Moto G: Settings → Developer Options → Revoke USB Debugging authorizations
3. Reconnect USB
4. Tap "Always allow" when prompt appears

### Issue: "adb: command not found"
**Solution:**
```bash
# Windows - Add to PATH
# Android SDK location: C:\Users\YourName\AppData\Local\Android\Sdk\platform-tools

# Or use full path
C:\Users\YourName\AppData\Local\Android\Sdk\platform-tools\adb.exe devices
```

### Issue: Can't access backend from app
**Solutions:**
1. **Check WiFi**: Both PC and Moto G on same network
2. **Firewall**: Allow port 8001 on Windows Firewall
3. **Use PC IP**: Not `localhost` or `127.0.0.1`
4. **Test connection**:
   ```bash
   # On Moto G, open Chrome
   # Go to: http://YOUR_PC_IP:8001/health
   # Should show: {"status":"ok",...}
   ```

### Issue: "Network request failed"
**Solution:**
Add network permissions in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Add inside <application> tag -->
<application
    android:usesCleartextTraffic="true"
    ...>
```

---

## 📊 Performance Tips

### Enable Hardware Acceleration
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:hardwareAccelerated="true"
    ...>
```

### Optimize APK Size
```bash
# Build release APK (smaller, optimized)
cd android
./gradlew assembleRelease

# Location: android/app/build/outputs/apk/release/app-release-unsigned.apk
```

### Enable ProGuard (Code Minification)
Edit `android/app/build.gradle`:
```gradle
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

---

## 🚢 Production Build Checklist

- [ ] Update API URL to production server
- [ ] Build release APK (not debug)
- [ ] Sign APK with keystore
- [ ] Test on multiple devices
- [ ] Enable ProGuard
- [ ] Optimize images/assets
- [ ] Test offline functionality
- [ ] Add error tracking (Sentry)
- [ ] Configure app permissions
- [ ] Test deep linking
- [ ] Add splash screen
- [ ] Configure app icon

---

## 📱 App Signing (for Production)

### Generate Keystore
```bash
keytool -genkey -v -keystore mcat-release-key.keystore \
  -alias mcat-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

### Configure Gradle
Edit `android/app/build.gradle`:
```gradle
android {
    signingConfigs {
        release {
            storeFile file('mcat-release-key.keystore')
            storePassword 'YOUR_STORE_PASSWORD'
            keyAlias 'mcat-key'
            keyPassword 'YOUR_KEY_PASSWORD'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### Build Signed APK
```bash
cd android
./gradlew assembleRelease
```

Signed APK: `android/app/build/outputs/apk/release/app-release.apk`

---

## 🎯 Quick Commands Reference

| Task | Command |
|------|---------|
| Check devices | `adb devices` |
| Install APK | `adb install app-debug.apk` |
| Reinstall APK | `adb install -r app-debug.apk` |
| Uninstall app | `adb uninstall com.mcatplatform.app` |
| Launch app | `adb shell am start -n com.mcatplatform.app/.MainActivity` |
| View logs | `adb logcat \| grep -i mcat` |
| Take screenshot | `adb shell screencap -p /sdcard/screenshot.png` |
| Copy file to device | `adb push file.apk /sdcard/` |
| Copy file from device | `adb pull /sdcard/file.txt` |
| Restart ADB | `adb kill-server && adb start-server` |

---

## ✅ Recommended: Start with PWA

For fastest deployment and testing:
1. ✅ Use **Option 1 (PWA)** first
2. ✅ Test all features on Moto G
3. ✅ Once satisfied, build **Option 2 (Native APK)**

PWA advantages:
- Instant updates (no reinstall needed)
- Works across all devices
- Smaller size
- Easier debugging

Native APK advantages:
- Offline support
- Better performance
- Native Android features
- App store distribution

---

**Ready to deploy!** 🚀

Start with Option 1 (PWA) for immediate testing, then build native APK when ready.

# 📱 Quick Start: Deploy to Moto G Device

**Fastest way to get the MCAT app on your Moto G!**

---

## 🚀 Option 1: PWA Deployment (5 Minutes) - RECOMMENDED

### Step 1: Get Your Computer's IP Address

**On Windows:**
```cmd
ipconfig
```
Look for "IPv4 Address" (e.g., `192.168.1.100`)

**Copy this IP address!**

### Step 2: Run the Automated Script

```bash
cd C:\dev\str8zero-agent-mesh\mcat-platform

# This script does EVERYTHING automatically!
./deploy-pwa-to-device.sh
```

The script will:
- ✅ Auto-detect your IP address
- ✅ Configure the app
- ✅ Start backend (Postgres, Redis, API)
- ✅ Start frontend (on your network)
- ✅ Give you the URL to open on your Moto G

### Step 3: Open on Moto G

1. **Connect Moto G to same WiFi** as your PC
2. **Open Chrome** on Moto G
3. **Go to the URL shown** (e.g., `http://192.168.1.100:3001`)
4. **You'll see the dark-themed login page!** 🌙

### Step 4: Install as PWA

1. In Chrome, tap **⋮** (menu)
2. Tap **"Add to Home Screen"**
3. Tap **"Add"**
4. **App installed!** Icon appears on home screen

### Step 5: Register & Use

1. Click **"Need an account? Register"**
2. Enter email, username, password
3. Click **"Create Account"**
4. **You're in!** Dark theme dashboard loads

---

## 🤖 Option 2: Native APK via ADB (15 Minutes)

### Prerequisites

- ✅ Node.js installed
- ✅ Android SDK/ADB installed
- ✅ USB cable

### Step 1: Enable USB Debugging on Moto G

1. **Settings** → **About Phone**
2. Tap **"Build Number"** 7 times
3. Go back to **Settings** → **Developer Options**
4. Enable **"USB Debugging"**

### Step 2: Build APK

```bash
cd C:\dev\str8zero-agent-mesh\mcat-platform

# This builds the native Android app
./build-android-apk.sh

# Then build with Gradle
cd frontend-mobile/android
./gradlew assembleDebug
```

APK will be at: `frontend-mobile/android/app/build/outputs/apk/debug/app-debug.apk`

### Step 3: Connect Moto G via USB

```bash
# Plug in USB cable
# On Moto G, tap "Always allow" when prompt appears

# Check device is connected
adb devices

# Should show:
# List of devices attached
# ABC123DEF    device
```

### Step 4: Install APK

```bash
cd C:\dev\str8zero-agent-mesh\mcat-platform

# Automated installer
./deploy-apk-via-adb.sh
```

Or manually:
```bash
adb install -r frontend-mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

### Step 5: Launch App

```bash
adb shell am start -n com.mcatplatform.app/.MainActivity
```

Or just tap the **MCAT Platform** icon on your Moto G!

---

## 🎯 Which Option Should I Use?

| Feature | PWA | Native APK |
|---------|-----|------------|
| **Setup Time** | 5 min | 15 min |
| **Difficulty** | Easy | Medium |
| **Requirements** | WiFi only | USB + ADB |
| **Updates** | Automatic | Manual reinstall |
| **Storage** | ~5 MB | ~15 MB |
| **Offline** | No | Yes (limited) |
| **Performance** | Fast | Faster |

**Recommendation:** Start with PWA (Option 1) for instant testing. Build native APK later if needed.

---

## 📋 Testing Checklist

After deployment, test these features:

- [ ] App opens with dark theme
- [ ] Register new account works
- [ ] Login works
- [ ] Dashboard shows stats
- [ ] Can browse questions
- [ ] Click on question starts practice mode
- [ ] Can highlight text
- [ ] Can eliminate options
- [ ] Submit answer works
- [ ] See AI analysis with diagnoses
- [ ] See adaptive overlay with steps
- [ ] See micro-drills
- [ ] Progress tab shows data
- [ ] Logout works
- [ ] Login again works

---

## 🐛 Troubleshooting

### Can't access app on Moto G (PWA)

**Check:**
1. Both PC and Moto G on same WiFi network
2. PC IP is correct (run `ipconfig` again)
3. Backend is running: `curl http://localhost:8001/health`
4. Windows Firewall allows port 3001

**Fix:**
```bash
# Stop and restart
Ctrl+C  # Stop the script
./deploy-pwa-to-device.sh  # Restart
```

### ADB can't find device

**Fix:**
1. Disconnect USB
2. On Moto G: Settings → Developer Options → Revoke USB Debugging
3. Reconnect USB
4. Tap "Always allow"
5. Run `adb devices` again

### App shows "Network Error"

**Fix:**
1. Check backend is running: `docker compose ps`
2. Check API health: `curl http://YOUR_IP:8001/health`
3. Update `.env.local` with correct IP
4. Restart frontend

### "device unauthorized" in ADB

**Fix:**
```bash
adb kill-server
adb start-server
adb devices
# Tap "Always allow" on Moto G prompt
```

---

## 🔧 Useful Commands

### View App Logs
```bash
adb logcat | grep -i mcat
```

### Uninstall App
```bash
adb uninstall com.mcatplatform.app
```

### Restart ADB Server
```bash
adb kill-server && adb start-server
```

### Take Screenshot
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

### Check Device Info
```bash
adb shell getprop ro.product.model    # Model
adb shell getprop ro.build.version.release  # Android version
```

---

## 📚 Full Documentation

For complete details, see:
- **DEPLOY_TO_ANDROID.md** - Complete deployment guide
- **PRODUCTION_MOBILE_APP_SUMMARY.md** - App features overview
- **MOBILE_APP_COMPLETE.md** - Technical documentation

---

## ✅ Success!

After deployment, you should have:

✨ **Dark-themed MCAT app** on your Moto G home screen  
🔐 **Working authentication** with your account  
📊 **Live dashboard** with your statistics  
🎯 **Interactive practice mode** with AI analysis  
📈 **Progress tracking** with adaptive overlays  

**Enjoy studying!** 🚀

---

**Need help?** Check DEPLOY_TO_ANDROID.md for detailed troubleshooting.

# QUICK FIX: Black Screen on Physical Device

## 🚨 The Problem
- ✅ Works in Simulator
- ❌ Black screen on iPhone/iPad

## 🎯 The Solution (30 seconds)

### Step 1: Find Info.plist
```
Xcode Navigator → Click "Info.plist" in your main app folder
```

### Step 2: Add Camera Permission

**METHOD A: Source Code View** (Recommended)
1. Right-click Info.plist → **Open As** → **Source Code**
2. Find the `<dict>` section
3. Paste this BEFORE the closing `</dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Dobby needs camera access to scan receipts and automatically categorize your expenses</string>
```

**METHOD B: Visual Editor**
1. Click Info.plist (opens in editor)
2. Click **+** button
3. Type: `Privacy - Camera Usage Description`
4. Set value: `Dobby needs camera access to scan receipts and automatically categorize your expenses`

### Step 3: Clean & Rebuild
```
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Delete app from your device
3. Run again
```

## ✅ What Should Happen

**First time running:**
```
App opens → Switch to Scan tab → Permission popup appears:

┌────────────────────────────────────────┐
│  "Dobby" Would Like to Access          │
│  the Camera                            │
│                                        │
│  Dobby needs camera access to scan    │
│  receipts and automatically categorize│
│  your expenses                        │
│                                        │
│  [Don't Allow]           [OK]         │
└────────────────────────────────────────┘

Tap OK → Camera opens!
```

## 🔍 Still Not Working?

Check the device console for errors:
1. Window → Devices and Simulators
2. Select your device
3. Click "Open Console"
4. Look for permission errors

## 📋 Complete Info.plist Template

See `Info.plist.template` for a ready-to-use template!

---

**That's it!** 99% of black screen issues are solved by adding camera permission. 🎉

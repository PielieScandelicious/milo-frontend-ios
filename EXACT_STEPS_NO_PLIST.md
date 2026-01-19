# 🎯 EXACT STEPS: Add Camera Permission (No Info.plist)

You don't have an Info.plist file visible in your project. That's normal for modern Xcode!

## 📱 Follow These EXACT Steps:

### 1️⃣ Click Your Project
```
In the left sidebar (Navigator):
Click the very top item - the blue Dobby icon
```

### 2️⃣ Select Your App Target
```
In the main editor area, you'll see two sections:

PROJECT          TARGETS
Dobby            Dobby          ← Click this one (your app)
                 Dobby Share Extension
```

### 3️⃣ Click the "Info" Tab
```
At the top of the editor, you'll see tabs:

[General] [Signing & Capabilities] [Resource Tags] [Info] [Build Settings]
                                                    ↑
                                              Click this
```

### 4️⃣ Add Camera Permission
```
In the Info tab, you should see a section with a list.

Look for a + button or right-click in the list area.

Click [+] or "Add Row"

Start typing: Privacy - Camera

Xcode will suggest: "Privacy - Camera Usage Description"

Select it.

In the Value field on the right, type:
Dobby needs camera access to scan receipts and automatically categorize your expenses
```

### 5️⃣ Press Enter to Save

### 6️⃣ Clean & Rebuild
```
1. Product → Clean Build Folder (⌘⇧K)
2. On your iPhone/iPad: Delete the Dobby app completely
3. In Xcode: Product → Run (⌘R)
```

---

## 🎬 What Should Happen

**After rebuilding:**
1. App opens on your device ✅
2. You see the View tab ✅
3. Tap Scan tab ✅
4. Permission popup appears asking for camera access ✅
5. Tap "OK" ✅
6. Camera opens! 📸

---

## ⚠️ Can't Find the Info Tab?

If you don't see an "Info" tab in your target settings, try this instead:

### Alternative Method: Create Info.plist

1. **Right-click** on your "Dobby" folder (where DobbyApp.swift is)
2. Select **New File...**
3. Scroll down to **Resource**
4. Select **Property List**
5. Click **Next**
6. Name it: `Info.plist`
7. Make sure **Dobby** target is checked
8. Click **Create**

Then:
1. **Right-click** the new Info.plist → **Open As** → **Source Code**
2. Delete everything and paste this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSCameraUsageDescription</key>
	<string>Dobby needs camera access to scan receipts and automatically categorize your expenses</string>
</dict>
</plist>
```

3. Save it
4. Clean build and run again

---

## 🆘 Still Black Screen?

Run this checklist:

- [ ] Added camera permission (NSCameraUsageDescription)
- [ ] Cleaned build folder (⌘⇧K)
- [ ] Deleted app from physical device
- [ ] Rebuilt the app
- [ ] No red errors in Xcode
- [ ] Deployment target matches your device iOS version

If all checked and still black screen:
1. Window → Devices and Simulators
2. Select your device
3. Click "Open Console"
4. Run the app
5. Look for error messages and send them to me

---

## 💡 Pro Tip

After you add the permission, you can verify it was added:

1. Build the app (⌘B)
2. Go to: Product → Show Build Folder in Finder
3. Navigate to: Products → Debug-iphoneos → Dobby.app
4. Right-click Dobby.app → Show Package Contents
5. Open Info.plist (should see your camera permission)

---

**The camera permission is 100% required. Add it using one of the methods above and your black screen will be fixed!** ✨

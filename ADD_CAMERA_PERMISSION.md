# How to Add Camera Permission (No Info.plist File)

## Modern Xcode Projects (iOS 14+)

If you don't see an Info.plist file, Xcode is managing it for you. Here's how to add camera permission:

## Method 1: Project Settings (Easiest) ⭐

### Step 1: Open Project Settings
1. Click on your **project name** at the top of the navigator (blue icon)
2. Select your **app target** (under TARGETS, not the project)
3. Click the **Info** tab at the top

### Step 2: Add Custom iOS Target Properties
1. Look for a section that might say **"Custom iOS Target Properties"** or just show a list of keys
2. **Right-click** in the list area → **Add Row** (or click the **+** button)
3. In the new row, start typing: `Privacy - Camera Usage Description`
4. Xcode should autocomplete it - select it
5. In the **Value** column, enter:
   ```
   Dobby needs camera access to scan receipts and automatically categorize your expenses
   ```

### Step 3: Clean & Rebuild
```
1. Product → Clean Build Folder (⌘⇧K)
2. Delete app from your device
3. Run again
```

---

## Method 2: Create Info.plist Manually

If you want to create an actual Info.plist file:

### Step 1: Create the File
1. **Right-click** on your app folder (where DobbyApp.swift is)
2. **New File...** → **Property List**
3. Name it: `Info.plist`
4. Make sure it's in your **app target** (check the target membership box)
5. Click **Create**

### Step 2: Add Content
1. **Right-click** on Info.plist → **Open As** → **Source Code**
2. Replace everything with this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSCameraUsageDescription</key>
	<string>Dobby needs camera access to scan receipts and automatically categorize your expenses</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Dobby needs access to your photos to import receipt images</string>
</dict>
</plist>
```

3. Save the file

### Step 3: Link to Target
1. Select your **project** → **app target** → **Build Settings**
2. Search for: `Info.plist File`
3. Set the value to: `Dobby/Info.plist` (or wherever you saved it)

### Step 4: Clean & Rebuild
```
1. Product → Clean Build Folder (⌘⇧K)
2. Delete app from your device
3. Run again
```

---

## Method 3: Check Existing Build Settings

Sometimes the Info.plist exists but isn't visible in the navigator.

### Step 1: Find Current Info.plist
1. Select your **project** → **app target** → **Build Settings**
2. Search for: `Info.plist File`
3. Look at the path shown - this is where your Info.plist is (or should be)

### Step 2: Navigate to That Path
1. In Finder, go to your project folder
2. Navigate to the path shown in Build Settings
3. If the file exists, edit it
4. If not, create it at that location

---

## Visual Guide for Method 1

```
Xcode Navigator
│
└─ 📱 Dobby (blue project icon) ← CLICK THIS
    │
    In the editor area, you'll see:
    ┌────────────────────────────────────┐
    │ PROJECT              TARGETS       │
    │ Dobby                Dobby  ← SELECT│
    │                      Dobby Share   │
    └────────────────────────────────────┘
    
    Top tabs:
    [General] [Signing & Capabilities] [Resource Tags] [Info] ← CLICK INFO
    
    In the Info tab:
    ┌─────────────────────────────────────────────────┐
    │ Custom iOS Target Properties                    │
    │ ┌────────────────┬──────────────────────┬─────┐│
    │ │ Key            │ Type    │ Value       │     ││
    │ ├────────────────┼─────────┼─────────────┼─────┤│
    │ │ [+] Add Row ← CLICK THIS                    ││
    │ └────────────────┴─────────┴─────────────┴─────┘│
    └─────────────────────────────────────────────────┘
```

---

## What to Enter

When you add the row, Xcode shows a dropdown. Type:
```
Privacy - Camera Usage Description
```

Xcode will autocomplete to:
```
NSCameraUsageDescription
```

In the Value field, enter:
```
Dobby needs camera access to scan receipts and automatically categorize your expenses
```

---

## Verify It's Added

After adding the permission:

1. **Build the app** (⌘B)
2. Look for any red errors in Xcode
3. If no errors, you're good!

To double-check:
1. Go to **Product** → **Build Settings**
2. Search for `Info.plist File`
3. Note the path
4. In Terminal:
   ```bash
   cd /path/to/your/project
   cat YourPath/Info.plist
   ```
5. You should see your camera permission

---

## Alternative: Use a Build Phase Script

If nothing else works, you can inject the permission at build time:

1. Select **target** → **Build Phases**
2. Click **+** → **New Run Script Phase**
3. Add this script:

```bash
INFO_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

if [ -f "$INFO_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'Dobby needs camera access to scan receipts'" "$INFO_PLIST" 2>/dev/null || true
fi
```

4. Move this phase **before** "Copy Bundle Resources"
5. Build again

---

## Still Having Issues?

If you can't find where to add it, let me know and I can help you:

1. **Screenshot** your Xcode project navigator
2. **Screenshot** your target's Info tab
3. Share any error messages you see

The permission **must** be added for the app to work on a physical device!

---

## Quick Troubleshooting

**Can't find Info tab?**
- Make sure you're clicking the **target** (under TARGETS), not the project

**Don't see "Add Row"?**
- Right-click in the white space under any existing rows
- Or look for a small **+** button at the bottom

**Changes not taking effect?**
- Clean build folder (⌘⇧K)
- Delete app from device completely
- Quit Xcode and reopen
- Rebuild

---

**Bottom line:** You need to add `NSCameraUsageDescription` somewhere. Method 1 (project settings) is the easiest! ✨

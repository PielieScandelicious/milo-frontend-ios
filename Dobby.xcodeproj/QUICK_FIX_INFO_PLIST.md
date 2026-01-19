# Quick Fix: Update Info.plist to Fix SLComposeServiceViewController Error

## The Problem

Your console shows:
```
SLComposeServiceViewController initWithCoder:
```

This means your Share Extension is using the **wrong base class**. The old Xcode template uses `SLComposeServiceViewController` but we're using `UIViewController` + SwiftUI.

## The 3-Minute Fix

### Step 1: Find the Correct Info.plist

In Xcode's **Project Navigator** (left sidebar):

```
📁 Dobby
   📁 Dobby (main app)
      📄 Info.plist          ← NOT this one
   📁 Dobby Share Extension
      📄 Info.plist          ← THIS ONE! ✅
      📄 ShareViewController.swift
      📄 ShareExtensionView.swift
```

**Click on:** `Dobby Share Extension/Info.plist`

### Step 2: Open as Source Code

**Right-click** on Info.plist → **Open As** → **Source Code**

### Step 3: Find NSExtension Section

Look for this section (usually near the bottom):

```xml
<key>NSExtension</key>
<dict>
    ...
</dict>
```

### Step 4: Replace the Entire NSExtension Section

**Delete everything between** `<key>NSExtension</key>` and its closing `</dict>`

**Replace with this:**

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

### Step 5: Save and Build

1. **Save** the file (Cmd + S)
2. **Clean Build Folder** (Cmd + Shift + K)
3. **Build** (Cmd + B)
4. **Run** and test

## What This Does

This tells iOS:
- ✅ Use `ShareViewController` (our UIKit + SwiftUI bridge)
- ✅ No storyboards
- ✅ Accept images and text
- ❌ Don't use `SLComposeServiceViewController` (old/deprecated)

## Visual Comparison

### ❌ OLD/WRONG Info.plist

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionMainStoryboard</key>        ← BAD!
    <string>MainInterface</string>              ← BAD!
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

**Problem:** Uses storyboard, defaults to `SLComposeServiceViewController`

### ✅ NEW/CORRECT Info.plist

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPrincipalClass</key>        ← GOOD!
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>  ← GOOD!
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
</dict>
```

**Benefit:** Uses our custom `ShareViewController`, loads SwiftUI view

## Verify It Worked

After rebuilding, the console should show:

### ✅ Success - You'll See:
```
📸 Image loaded: 245678 bytes
🔍 Starting OCR...
📝 Extracted text (432 chars):
ALDI BELGIUM
...
🏪 Detected store: ALDI
```

### ❌ Still Broken - You'll See:
```
SLComposeServiceViewController initWithCoder:
```

If still broken, you edited the **wrong Info.plist** or didn't save/rebuild.

## Alternative: Use Property List Editor

If you prefer the visual editor:

1. **Click** Info.plist (normal click, not right-click)
2. **Expand** `NSExtension`
3. **Find** `NSExtensionMainStoryboard` → **DELETE IT** (minus button)
4. **Add** new row (plus button)
5. **Key:** `NSExtensionPrincipalClass`
6. **Type:** String
7. **Value:** `$(PRODUCT_MODULE_NAME).ShareViewController`

## Common Mistakes

### Mistake 1: Editing Main App's Info.plist

**Wrong:** Editing `Dobby/Info.plist`  
**Right:** Editing `Dobby Share Extension/Info.plist`

### Mistake 2: Not Cleaning Build

After changing Info.plist:
- Clean Build Folder (Cmd + Shift + K)
- Rebuild (Cmd + B)

### Mistake 3: MainInterface.storyboard Still There

If you have `MainInterface.storyboard` in your Share Extension folder:
- **Delete it** (Move to Trash)
- It's not used anymore

### Mistake 4: Wrong Module Name

If your Share Extension target is named something other than "Dobby Share Extension", the principal class might be different.

**Check:** Your target name in Xcode → Use that in the format:
```
TargetName.ShareViewController
```

But `$(PRODUCT_MODULE_NAME)` should work automatically.

## One-Minute Checklist

- [ ] Found correct Info.plist (`Dobby Share Extension/Info.plist`)
- [ ] Opened as Source Code
- [ ] Replaced NSExtension section with correct XML
- [ ] Saved file
- [ ] Cleaned build folder
- [ ] Rebuilt
- [ ] Tested - no more `SLComposeServiceViewController` error

## Still Not Working?

Show me:
1. The entire NSExtension section from your Info.plist
2. Your ShareViewController.swift first 10 lines
3. Your project structure (Share Extension folder contents)

This is a configuration issue, not a code issue. Once Info.plist is correct, everything will work! 🎯

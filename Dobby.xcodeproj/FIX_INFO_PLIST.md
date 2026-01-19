# URGENT FIX: Share Extension Info.plist Configuration

## Problem

You're seeing this error:
```
SLComposeServiceViewController initWithCoder:
```

This means your Share Extension's **Info.plist** is configured to use the old `SLComposeServiceViewController` which is incompatible with our SwiftUI implementation.

## Solution

You need to update your **Share Extension's Info.plist** file.

### Step-by-Step Fix

1. **In Xcode Navigator**, find your Share Extension folder (e.g., "Dobby Share Extension")
2. **Click on Info.plist** in that folder
3. **Find the NSExtension section**
4. **Look for these keys and DELETE them:**
   - `NSExtensionMainStoryboard` ❌ DELETE
   - Any reference to "MainInterface.storyboard" ❌ DELETE

5. **Update NSExtensionPrincipalClass:**

   Find:
   ```
   NSExtensionPrincipalClass
   ```
   
   Change the value to:
   ```
   $(PRODUCT_MODULE_NAME).ShareViewController
   ```

### Complete Info.plist NSExtension Section

Your Info.plist should look like this:

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

### Important: What NOT to Have

❌ **DO NOT have:**
```xml
<key>NSExtensionMainStoryboard</key>
<string>MainInterface</string>
```

❌ **DO NOT import Social framework**

❌ **DO NOT have SLComposeServiceViewController** anywhere

### Visual Guide (Info.plist Editor View)

When viewing Info.plist in Xcode, expand `NSExtension`:

```
▼ NSExtension (Dictionary)
    ▼ NSExtensionAttributes (Dictionary)
        ▼ NSExtensionActivationRule (Dictionary)
            NSExtensionActivationSupportsImageWithMaxCount (Number) = 1
            NSExtensionActivationSupportsText (Boolean) = YES
            NSExtensionActivationSupportsFileWithMaxCount (Number) = 1
    NSExtensionPrincipalClass (String) = $(PRODUCT_MODULE_NAME).ShareViewController
    NSExtensionPointIdentifier (String) = com.apple.share-services
```

### Alternative: Right-Click → Open As → Source Code

If you prefer to edit the raw XML:

1. **Right-click Info.plist**
2. **Open As → Source Code**
3. **Find the NSExtension section**
4. **Replace it with the XML above**

## Why This Happens

When you create a Share Extension in Xcode using the template, it defaults to the **old UIKit template** which uses:
- `SLComposeServiceViewController` (deprecated)
- A storyboard-based UI
- The Social framework

We're using a **modern approach** with:
- Pure `UIViewController` + SwiftUI
- No storyboards
- No Social framework

## Verify the Fix

After updating Info.plist:

1. **Clean Build Folder** (Cmd + Shift + K)
2. **Rebuild** the Share Extension target
3. **Run** on device/simulator
4. **Share an image** to Dobby

You should NO LONGER see:
- ❌ `SLComposeServiceViewController initWithCoder:`
- ❌ Social framework errors

You SHOULD see:
- ✅ Your SwiftUI extension opens
- ✅ Processing screen appears
- ✅ Review screen shows

## Complete Checklist

- [ ] Info.plist has `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ShareViewController`
- [ ] Info.plist does NOT have `NSExtensionMainStoryboard`
- [ ] No `MainInterface.storyboard` file in Share Extension folder
- [ ] ShareViewController.swift exists and inherits from `UIViewController` (not SLComposeServiceViewController)
- [ ] Social framework is NOT imported anywhere
- [ ] Clean build folder
- [ ] Rebuild
- [ ] Test

## Still Getting the Error?

If you still see `SLComposeServiceViewController`:

### Check 1: Target Membership

Make sure `ShareViewController.swift` is in the **Share Extension target**, not the main app:

1. Select `ShareViewController.swift`
2. Open **File Inspector** (right panel)
3. Check **Target Membership**
4. ✅ Share Extension should be checked
5. ❌ Main app should NOT be checked

### Check 2: Correct File

Make sure you're editing the **Share Extension's Info.plist**, not the main app's:

- Main app: `Dobby/Info.plist`
- Share Extension: `Dobby Share Extension/Info.plist`

You need to edit the **Share Extension one**!

### Check 3: Class Name

In `ShareViewController.swift`, verify:

```swift
class ShareViewController: UIViewController {  // ✅ UIViewController
    // NOT: SLComposeServiceViewController  ❌
```

### Check 4: Old Files

Delete these if they exist in Share Extension folder:
- `MainInterface.storyboard` ❌
- Any file referencing `SLComposeServiceViewController` ❌

## Quick Fix Script

If you want to verify your Info.plist is correct, the NSExtension dictionary should have exactly these keys:

```
NSExtension
├── NSExtensionAttributes
│   └── NSExtensionActivationRule
│       ├── NSExtensionActivationSupportsImageWithMaxCount: 1
│       ├── NSExtensionActivationSupportsText: true
│       └── NSExtensionActivationSupportsFileWithMaxCount: 1
├── NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShareViewController
└── NSExtensionPointIdentifier: com.apple.share-services
```

## After the Fix

Once Info.plist is correct, you should see in console:

```
📸 Image loaded: 245678 bytes
🔍 Starting OCR...
📝 Extracted text (432 chars):
...
```

NOT:
```
SLComposeServiceViewController initWithCoder:  ❌
```

## Summary

**Problem:** Info.plist points to old `SLComposeServiceViewController`  
**Solution:** Update `NSExtensionPrincipalClass` to use `ShareViewController`  
**Remove:** Any storyboard references  
**Result:** SwiftUI extension loads correctly  

Make this change and rebuild - it should fix the error immediately! 🚀

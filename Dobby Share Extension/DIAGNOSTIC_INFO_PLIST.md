# Quick Diagnostic: Why Is SLComposeServiceViewController Loading?

## The Issue

`SLComposeServiceViewController` is an **old, deprecated class** from iOS 8. You should **never** see this in your console if using modern SwiftUI extensions.

## Quick Check: Is Info.plist Correct?

Run this command in Terminal from your project directory:

```bash
plutil -p "Dobby Share Extension/Info.plist" | grep -A 5 "NSExtension"
```

### ✅ Good Output (What You Want):
```
"NSExtension" => {
    ...
    "NSExtensionPrincipalClass" => "$(PRODUCT_MODULE_NAME).ShareViewController"
    ...
}
```

### ❌ Bad Output (The Problem):
```
"NSExtension" => {
    ...
    "NSExtensionMainStoryboard" => "MainInterface"
    ...
}
```

OR if you see **no** `NSExtensionPrincipalClass` at all.

## Manual Info.plist Check

1. Open your Share Extension's Info.plist
2. View as **Source Code** (right-click → Open As → Source Code)
3. Search (Cmd + F) for: `SLCompose`
   - **Should find:** 0 results ✅
   - **If you find any:** ❌ Problem! Remove them!

4. Search for: `MainInterface`
   - **Should find:** 0 results ✅
   - **If you find any:** ❌ Problem! Remove them!

5. Search for: `NSExtensionPrincipalClass`
   - **Should find:** 1 result ✅
   - **Value should be:** `$(PRODUCT_MODULE_NAME).ShareViewController`
   - **If not found or different:** ❌ Problem!

## Where SLComposeServiceViewController Comes From

This class is loaded when your Info.plist has:

### Scenario 1: Storyboard-Based (Old Template)
```xml
<key>NSExtensionMainStoryboard</key>
<string>MainInterface</string>
```

**Fix:** Delete this entire key-value pair.

### Scenario 2: No Principal Class Specified
```xml
<key>NSExtension</key>
<dict>
    <!-- Missing NSExtensionPrincipalClass -->
</dict>
```

**Fix:** Add:
```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
```

### Scenario 3: Wrong Class Name
```xml
<key>NSExtensionPrincipalClass</key>
<string>SLComposeServiceViewController</string>
```

**Fix:** Change to:
```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
```

## Complete Correct Info.plist NSExtension

Your entire NSExtension section should look **exactly** like this:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <string>TRUEPREDICATE</string>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
</dict>
```

**Key points:**
- `NSExtensionPrincipalClass` points to YOUR class
- NO `NSExtensionMainStoryboard`
- NO references to storyboards at all

## Verify Your ShareViewController

Your `ShareViewController.swift` should start like this:

```swift
import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ Using ShareViewController (not SLComposeServiceViewController)")
        // ... rest of code
    }
}
```

**Must be:** `UIViewController`, NOT `SLComposeServiceViewController`!

## Test After Each Change

After updating Info.plist:

1. **Save** file
2. **Clean Build Folder** (Cmd + Shift + K)
3. **Quit Xcode** completely
4. **Delete DerivedData:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
5. **Reopen Xcode**
6. **Build** (Cmd + B)
7. **Run** and test

## Still Not Working? Check These:

### Check 1: Are You Editing The Right File?

You might have multiple Info.plist files:

```
📁 Project
   📁 Dobby (main app)
      📄 Info.plist         ← Not this one!
   📁 Dobby Share Extension
      📄 Info.plist         ← THIS one! ✅
```

### Check 2: Is ShareViewController in Share Extension Target?

1. Click on `ShareViewController.swift`
2. Open **File Inspector** (right panel)
3. Check **Target Membership**
4. **Share Extension** should be checked ✅
5. **Main app** should NOT be checked ❌

### Check 3: Does MainInterface.storyboard Exist?

If you have `MainInterface.storyboard` in your Share Extension folder:

**DELETE IT!** It's not used and causes confusion.

### Check 4: Check Build Settings

1. Select **Share Extension target**
2. **Build Settings** tab
3. Search for: `Principal Class`
4. Should be empty or match Info.plist

## The Nuclear Option

If NOTHING works after all these checks:

### Complete Rebuild:

1. **Delete** the Share Extension target completely
2. **Close Xcode**
3. **Delete DerivedData**
4. **Reopen Xcode**
5. **Create NEW Share Extension target** from scratch
6. **Immediately** (before adding any code):
   - Update Info.plist
   - Delete MainInterface.storyboard
   - Delete default ShareViewController.swift
7. **Add your custom files**
8. **Build and test**

## Console Test

Add this to your `ShareViewController` to prove it's loading:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🎯 ShareViewController.viewDidLoad()")
    print("📱 Class: \(String(describing: type(of: self)))")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    // ... rest of code
}
```

### ✅ Success Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 ShareViewController.viewDidLoad()
📱 Class: ShareViewController
━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### ❌ Failure Output:
```
SLComposeServiceViewController initWithNibName:bundle:
```

If you see the failure, your Info.plist **definitely** isn't correct.

## Final Checklist

Before asking for more help, verify:

- [ ] Info.plist has `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ShareViewController`
- [ ] Info.plist has NO `NSExtensionMainStoryboard`
- [ ] No `MainInterface.storyboard` file exists
- [ ] `ShareViewController` inherits from `UIViewController`, not `SLComposeServiceViewController`
- [ ] `ShareViewController.swift` is in Share Extension target only
- [ ] Cleaned build folder
- [ ] Deleted DerivedData
- [ ] Rebuilt from scratch
- [ ] Testing on actual device (not just simulator)

## Last Resort Debug

Add breakpoint in `ShareViewController.viewDidLoad()`:

- **If breakpoint hits:** ✅ Your class is loading (check why UI might be wrong)
- **If breakpoint doesn't hit:** ❌ Wrong class loading (Info.plist issue)

## Summary

`SLComposeServiceViewController` only loads if:

1. Info.plist references it (directly or via storyboard)
2. Info.plist doesn't specify correct principal class
3. Xcode is using cached/old configuration

**The fix is always in Info.plist!**

Once Info.plist is correct and DerivedData is cleared, it will work immediately. There's no code change needed - `ShareViewController.swift` is already correct! 🎯

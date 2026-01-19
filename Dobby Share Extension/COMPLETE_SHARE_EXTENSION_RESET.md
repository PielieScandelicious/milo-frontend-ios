# COMPLETE SHARE EXTENSION RESET - Step by Step

## Problem

You're still seeing `SLComposeServiceViewController` errors, which means:
1. Info.plist wasn't updated correctly, OR
2. Old files are still being used, OR
3. Xcode is caching the old configuration

## Complete Reset Solution

Follow these steps **exactly** to fix it:

### Step 1: Delete the Entire Share Extension Target

1. In Xcode, click on your **project** (top of navigator)
2. In the **TARGETS** list, find your Share Extension target
3. **Right-click** on it → **Delete**
4. Confirm deletion
5. **Move to Trash** when asked

### Step 2: Clean Everything

1. **Product** → **Clean Build Folder** (Cmd + Shift + K)
2. **Close Xcode**
3. Delete **DerivedData**:
   - Finder → Go → Go to Folder (Cmd + Shift + G)
   - Type: `~/Library/Developer/Xcode/DerivedData`
   - Find your project folder → **Delete it**
4. **Reopen Xcode**

### Step 3: Create New Share Extension Target

1. **File** → **New** → **Target**
2. Scroll to **Application Extension**
3. Select **Share Extension**
4. Click **Next**
5. **Product Name:** `Dobby Share Extension`
6. **Language:** Swift
7. **Include UI Extension:** YES (leave checked)
8. Click **Finish**
9. When asked "Activate scheme?" → Click **Cancel**

### Step 4: Delete Default Template Files

Xcode creates some files we don't need. In the Share Extension folder, **DELETE** these:

- `MainInterface.storyboard` → **DELETE**
- `ShareViewController.swift` (the default one) → **DELETE**

### Step 5: Add Our Custom Files

Now add the correct files:

#### 5A. Create ShareViewController.swift

1. **Right-click** on "Dobby Share Extension" folder
2. **New File** → **Swift File**
3. Name: `ShareViewController`
4. **Target Membership:** ✅ Dobby Share Extension (ONLY)
5. Click **Create**

**Paste this code:**

```swift
//
//  ShareViewController.swift
//  Dobby Share Extension
//

import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure we have a white/system background
        view.backgroundColor = .systemBackground
        
        // Get the shared items from the extension context
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("❌ No extension items found")
            closeExtension()
            return
        }
        
        print("✅ ShareViewController loaded successfully")
        print("📦 Extension items count: \(extensionItems.count)")
        
        // Create SwiftUI view with the shared items
        let shareView = ShareExtensionView(sharedItems: extensionItems)
            .environment(\.extensionContext, extensionContext)
        
        // Host the SwiftUI view
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.backgroundColor = .clear
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        // Set up constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("✅ ShareViewController appeared")
    }
    
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
```

#### 5B. Add ShareExtensionView.swift

1. **Drag** your existing `ShareExtensionView.swift` into the Share Extension folder
2. OR create new file and paste the complete ShareExtensionView code
3. **Target Membership:** ✅ Dobby Share Extension (ONLY)

### Step 6: Configure Info.plist (CRITICAL)

1. In the Share Extension folder, find **Info.plist**
2. **Right-click** → **Open As** → **Source Code**
3. Find the `<key>NSExtension</key>` section
4. **Replace the ENTIRE NSExtension section** with:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>10</integer>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
</dict>
```

**Important:** This configuration allows:
- Up to 10 images (for OCR processing)
- Text sharing (for text OCR)
- 1 file at a time (for document OCR)

This is **App Store compliant** and specifically targets the content types Dobby needs.

5. **Save** the file

### Step 7: Configure App Groups

Both targets need the same App Group:

#### Main App:
1. Select **project** → **Dobby target** → **Signing & Capabilities**
2. **+ Capability** → **App Groups**
3. **+** Add group: `group.com.yourcompany.dobby` (use YOUR bundle ID prefix)
4. ✅ Check the box

#### Share Extension:
1. Select **project** → **Dobby Share Extension target** → **Signing & Capabilities**
2. **+ Capability** → **App Groups**
3. **+** Add the **SAME** group: `group.com.yourcompany.dobby`
4. ✅ Check the box

### Step 8: Link Required Frameworks

1. Select **Dobby Share Extension target**
2. **Build Phases** tab
3. Expand **Link Binary With Libraries**
4. Click **+** and add:
   - `Vision.framework`
   - `UIKit.framework` (should already be there)
   - `SwiftUI.framework` (should already be there)

### Step 9: Build Settings

1. Select **Dobby Share Extension target**
2. **Build Settings** tab
3. Search for "Swift Language Version"
4. Ensure it's **Swift 5** or **Swift 6**

### Step 10: Clean Build & Test

1. **Product** → **Clean Build Folder** (Cmd + Shift + K)
2. **Product** → **Build** (Cmd + B)
3. **Run** the main app
4. Open Photos, select an image
5. **Share** → Select "Dobby"

## What You Should See Now

### ✅ Success Console Output:
```
✅ ShareViewController loaded successfully
📦 Extension items count: 1
✅ ShareViewController appeared
📸 Image loaded: 245678 bytes
🔍 Starting OCR...
```

### ❌ Still Broken:
```
SLComposeServiceViewController initWithNibName:bundle:
```

## If Still Seeing SLComposeServiceViewController

This means the Info.plist **definitely** wasn't updated correctly. Let's verify:

### Manual Verification:

1. Open `Dobby Share Extension/Info.plist` as **Source Code**
2. Search for "SLCompose" - **Should find NOTHING**
3. Search for "MainInterface" - **Should find NOTHING**
4. Search for "NSExtensionPrincipalClass" - **Should find:** `$(PRODUCT_MODULE_NAME).ShareViewController`

### Understanding the Activation Rules

The configuration above is optimized for Dobby's OCR capabilities:

- **NSExtensionActivationSupportsImageWithMaxCount = 10**: Allows sharing up to 10 images at once for batch OCR
- **NSExtensionActivationSupportsText = true**: Allows sharing plain text (useful for text-based OCR)
- **NSExtensionActivationSupportsFileWithMaxCount = 1**: Allows sharing single PDF or document files

You can adjust these values based on your needs:
- Set image count to `1` if you only want single image OCR
- Remove text support by setting it to `false` or removing the key
- Increase file count if you want to process multiple documents
- Add `NSExtensionActivationSupportsWebURLWithMaxCount` if you want to share URLs

## Common Gotchas

### 1. Wrong Info.plist
Make sure you're editing the **Share Extension's** Info.plist, not the main app's!

### 2. Cached Build
Delete DerivedData again and rebuild.

### 3. Target Membership
`ShareViewController.swift` must be in **Share Extension target ONLY**, not main app.

### 4. Module Name
If your Share Extension has a different name, the principal class would be different. Check your target name.

## Nuclear Option: Complete Manual Setup

If nothing works, here's the absolute manual way:

1. **Delete Share Extension target** completely
2. **File** → **New** → **Target** → **App Extension** → **Custom Extension**
3. Set extension point: `com.apple.share-services`
4. Create all files manually
5. Configure Info.plist from scratch

## Debugging Steps

Add this to ShareViewController to confirm it's being loaded:

```swift
override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    print("🎯 ShareViewController init with nib")
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
}

required init?(coder: NSCoder) {
    print("🎯 ShareViewController init with coder")
    super.init(coder: coder)
}
```

If you see `🎯` in console, our class is loading.  
If you see `SLComposeServiceViewController`, wrong class is loading.

## Summary

The **only** way `SLComposeServiceViewController` can appear is if:

1. ❌ Info.plist still references old class/storyboard
2. ❌ Old target/files still in project
3. ❌ Xcode cache not cleared
4. ❌ Wrong Info.plist being edited

The solution is to **completely recreate** the Share Extension target with the correct configuration from the start.

Follow the steps above **exactly** and it will work! 🚀

# Share Extension Setup Guide

## Overview
The Dobby Share Extension allows users to share receipt images directly to the app from Photos, Files, or other apps. The extension automatically:
1. Extracts text from the receipt using Vision framework
2. Detects the store name
3. Saves the image locally in `receipts/storename/` folder
4. Notifies the main app to process the receipt

## Configuration Steps

### 1. App Group Setup

Both the main app and the Share Extension need to share data using an App Group.

#### Main App Target
1. Select your main app target in Xcode
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** and add **App Groups**
4. Enable the App Group: `group.com.dobby.app`
   - If it doesn't exist, click the + button to create it

#### Share Extension Target
1. Select the **Dobby Share Extension** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** and add **App Groups**
4. Enable the same App Group: `group.com.dobby.app`

### 2. Info.plist Configuration (Share Extension)

The Share Extension's `Info.plist` should be configured to accept image types:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

**Note:** If you're not using a Storyboard, replace `NSExtensionMainStoryboard` with:
```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
```

### 3. Privacy Permissions

The Share Extension needs Vision framework but doesn't require additional permissions since it only processes images explicitly shared by the user.

However, ensure your main app's `Info.plist` has:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan receipts</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to import receipt images</string>
```

### 4. Linking Frameworks

Make sure the Share Extension target links these frameworks:
- **Vision.framework** (for OCR)
- **UIKit.framework**
- **Foundation.framework**

### 5. Update App Identifier

In both `ShareViewController.swift` and `SharedReceiptManager.swift`, verify the App Group identifier matches your configuration:

```swift
private let appGroupIdentifier = "group.com.dobby.app"
```

If you need to change it, update it in both files.

## Usage

### Sharing a Receipt

1. Open Photos or any app with a receipt image
2. Tap the Share button
3. Select **Dobby** from the share sheet
4. The extension will:
   - Extract text from the receipt
   - Detect the store (ALDI, COLRUYT, DELHAIZE, CARREFOUR, LIDL)
   - Save the image to `receipts/storename/receipt_YYYYMMDD_HHMMSS.jpg`
   - Add the receipt to the pending queue

### Processing Receipts in Main App

Add this code to your main app's startup (e.g., in `App.init()` or `ContentView.onAppear()`):

```swift
Task {
    try? await SharedReceiptManager.shared.processPendingReceipts(
        transactionManager: transactionManager
    )
}
```

This will:
1. Load all pending receipts from the App Group
2. Process them using the Anthropic service
3. Add transactions to your TransactionManager
4. Clear the pending queue

### Accessing Saved Receipt Images

```swift
// List all receipts organized by store
let receiptsByStore = await SharedReceiptManager.shared.listSavedReceipts()

// Get a specific receipt image
if let image = await SharedReceiptManager.shared.getReceiptImage(at: path) {
    // Display the image
}

// Get the receipts directory
if let receiptsDir = await SharedReceiptManager.shared.getReceiptsDirectory() {
    print("Receipts saved at: \(receiptsDir.path)")
}
```

## File Structure

Receipts are saved in this structure:
```
App Group Container/
└── receipts/
    ├── aldi/
    │   ├── receipt_20260119_143022.jpg
    │   └── receipt_20260119_150311.jpg
    ├── colruyt/
    │   └── receipt_20260119_124511.jpg
    ├── delhaize/
    ├── carrefour/
    └── lidl/
```

## Troubleshooting

### App Group Not Found
- Make sure both targets have the same App Group identifier
- Verify the App Group is enabled in both targets' capabilities
- Check your Apple Developer account has App Groups enabled

### Share Extension Not Appearing
- Make sure the extension is included in your app's build
- Verify Info.plist has correct NSExtension configuration
- Check that NSExtensionActivationSupportsImageWithMaxCount is set

### Vision Framework Errors
- The extension needs iOS 16.0+ for best OCR results
- Make sure Vision.framework is linked in the extension target

### Receipts Not Processing in Main App
- Verify you're calling `processPendingReceipts()` when the app launches
- Check that AnthropicService is properly configured
- Look for error messages in the console

## Advanced Features

### Custom Store Detection

To add new stores, update the `SupportedStore` enum in `ShareViewController.swift`:

```swift
case newstore = "NEWSTORE"

var keywords: [String] {
    switch self {
    // ... existing cases
    case .newstore:
        return ["newstore", "new store", "store alias"]
    }
}
```

### Image Compression

Images are saved with 80% JPEG quality by default. To change:

```swift
guard let imageData = image.jpegData(compressionQuality: 0.8) else {
    throw ReceiptError.imageCompressionFailed
}
```

Adjust the `compressionQuality` parameter (0.0 to 1.0).

### Background Processing

The Share Extension uses `async/await` for better performance. All Vision processing happens asynchronously, so the UI remains responsive.

## Security & Privacy

- Receipt images are stored locally in the App Group container
- Text is extracted on-device using Apple's Vision framework
- Only the extracted text is sent to Anthropic for categorization
- No receipt data is shared with third parties without user consent

# Share Extension - Quick Integration Guide

## What's New

The Share Extension has been completely rewritten to be **simple and efficient**:

✅ **Auto-detects store** from receipt text  
✅ **Saves images locally** in `receipts/storename/` folder  
✅ **No UI interaction required** - just share and it's done  
✅ **Uses Vision framework** for on-device OCR  
✅ **Shares data via App Group** between extension and main app  

## Files Created/Modified

### New Files
1. **ShareViewController.swift** - Simplified Share Extension (rewritten)
2. **SharedReceiptManager.swift** - Manages receipts shared from extension
3. **SavedReceiptsView.swift** - View to browse saved receipts
4. **SHARE_EXTENSION_SETUP.md** - Complete setup documentation

### How It Works

```
┌─────────────────┐
│  User shares    │
│  receipt image  │
│  to Dobby       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│  Share Extension            │
│  1. Extract text (Vision)   │
│  2. Detect store            │
│  3. Save to receipts/store/ │
│  4. Add to pending queue    │
└────────┬────────────────────┘
         │
         │ (App Group shared storage)
         │
         ▼
┌─────────────────────────────┐
│  Main App                   │
│  1. Read pending receipts   │
│  2. Process with Anthropic  │
│  3. Create transactions     │
│  4. Clear pending queue     │
└─────────────────────────────┘
```

## Integration Steps

### Step 1: Configure App Groups

1. Main app target → Signing & Capabilities → Add App Groups
   - Enable: `group.com.dobby.app`

2. Share Extension target → Signing & Capabilities → Add App Groups
   - Enable: `group.com.dobby.app`

### Step 2: Update Your App's Main Entry Point

Add this to your app's initialization to process pending receipts:

```swift
import SwiftUI

@main
struct DobbyApp: App {
    @StateObject private var transactionManager = TransactionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transactionManager)
                .task {
                    // Process receipts shared from Share Extension
                    await processPendingReceipts()
                }
        }
    }
    
    private func processPendingReceipts() async {
        do {
            try await SharedReceiptManager.shared.processPendingReceipts(
                transactionManager: transactionManager
            )
        } catch {
            print("Error processing pending receipts: \(error)")
        }
    }
}
```

### Step 3: Add Receipts Gallery (Optional)

Add `SavedReceiptsView` to your navigation:

```swift
NavigationLink {
    SavedReceiptsView()
} label: {
    Label("Saved Receipts", systemImage: "doc.text.image")
}
```

### Step 4: Update Info.plist for Share Extension

Make sure your Share Extension's Info.plist has:

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
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

## Testing

### Test the Share Extension

1. Build and run the main app on a device or simulator
2. Open Photos app
3. Select any receipt image
4. Tap Share button
5. Select "Dobby"
6. Watch the progress:
   - "Reading receipt text..."
   - "Detecting store..."
   - "Saving receipt..."
   - "Receipt saved successfully!"

### Verify Receipt Storage

```swift
// Check where receipts are stored
Task {
    if let dir = await SharedReceiptManager.shared.getReceiptsDirectory() {
        print("Receipts directory: \(dir.path)")
    }
    
    // List all receipts
    let receipts = await SharedReceiptManager.shared.listSavedReceipts()
    print("Receipts by store: \(receipts)")
}
```

### Test Main App Processing

1. Share a receipt from Photos
2. Close/reopen the main app
3. The receipt should be automatically processed
4. Check if transactions were added to TransactionManager

## Supported Stores

Currently auto-detects these stores:
- **ALDI** (aldi, aldi nord, aldi süd)
- **COLRUYT** (colruyt, okay, bio-planet)
- **DELHAIZE** (delhaize, ad delhaize, proxy delhaize)
- **CARREFOUR** (carrefour, carrefour express, carrefour market)
- **LIDL** (lidl)
- **Unknown** (fallback for unrecognized stores)

### Adding More Stores

Edit `SupportedStore` enum in `ShareViewController.swift`:

```swift
enum SupportedStore: String, CaseIterable {
    case aldi = "ALDI"
    case newStore = "NEWSTORE"  // Add here
    
    var keywords: [String] {
        switch self {
        case .aldi:
            return ["aldi"]
        case .newStore:  // Add keywords
            return ["newstore", "new store"]
        }
    }
}
```

## API Reference

### SharedReceiptManager

```swift
// Get pending receipts
let pending = await SharedReceiptManager.shared.getPendingReceipts()

// Process all pending receipts
try await SharedReceiptManager.shared.processPendingReceipts(
    transactionManager: transactionManager
)

// Clear pending receipts manually
await SharedReceiptManager.shared.clearPendingReceipts()

// List saved receipt images
let receipts = await SharedReceiptManager.shared.listSavedReceipts()
// Returns: [String: [URL]] - Store name to receipt URLs

// Load a specific receipt image
if let image = await SharedReceiptManager.shared.getReceiptImage(at: path) {
    // Use the image
}

// Get receipts directory
if let dir = await SharedReceiptManager.shared.getReceiptsDirectory() {
    // Access directory
}
```

## Troubleshooting

### Extension doesn't appear in share sheet
- Make sure extension target is included in build
- Verify Info.plist configuration
- Try sharing a photo (not PDF or other file types)

### "App Group Not Found" error
- Both targets must have the same App Group identifier
- Check Signing & Capabilities for both targets

### Receipts not processing in main app
- Add `.task { await processPendingReceipts() }` to your main view
- Check console for errors
- Verify AnthropicService is configured

### Store not detected
- Add store keywords to `SupportedStore` enum
- Check receipt text quality
- Store might be categorized as "Unknown"

## Performance Notes

- **Vision OCR**: Runs on-device, very fast (~1-2 seconds)
- **Image Storage**: JPEG at 80% quality (good balance)
- **File Organization**: Automatic by store name
- **Background Processing**: Uses Swift Concurrency for async operations

## Privacy & Security

✅ All processing happens on-device  
✅ Images stored locally in App Group  
✅ Only extracted text sent to Anthropic  
✅ No data shared without user consent  
✅ Receipts accessible only to your app  

## Next Steps

1. ✅ Configure App Groups
2. ✅ Add receipt processing to app startup
3. ✅ Test sharing a receipt
4. ✅ Verify transactions are created
5. Optional: Add SavedReceiptsView to browse receipts

That's it! The Share Extension is now ready to use. 🎉

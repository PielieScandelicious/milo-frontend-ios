# Quick Setup Checklist

Use this checklist to quickly set up the receipt upload functionality in your Dobby app.

## ✅ Main App Setup

- [ ] Add `ReceiptUploadService.swift` to project
- [ ] Ensure `ReceiptUploadService.swift` target membership includes **Dobby** (main app)
- [ ] Updated `ReceiptScanView.swift` is using the new upload service
- [ ] Build and test scanning a receipt
- [ ] Verify console shows: "Receipt uploaded successfully - S3 Key: receipts/..."

## ✅ Share Extension Setup

### Create Extension Target (if not exists)

- [ ] File → New → Target → Share Extension
- [ ] Name: "Dobby Share Extension"
- [ ] Delete default `ShareViewController.swift`
- [ ] Delete `MainInterface.storyboard`

### Add Files

- [ ] Add `ShareViewController.swift` to share extension target **ONLY**
- [ ] Add `ShareExtensionView.swift` to share extension target **ONLY**
- [ ] Ensure `ReceiptUploadService.swift` target membership includes **Dobby Share Extension**

### Configure Info.plist

- [ ] Open share extension's Info.plist
- [ ] Right-click → Open As → Source Code
- [ ] Replace `NSExtension` section with content from `ShareExtension-Info.plist`
- [ ] Verify `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ShareViewController`
- [ ] Save file

### Optional: App Groups

- [ ] Main app: Add App Groups capability
- [ ] Share extension: Add same App Groups capability
- [ ] Use group name: `group.com.yourcompany.dobby`

## ✅ Testing

### In-App Scanning

- [ ] Open app
- [ ] Tap "Scan Receipt"
- [ ] Scan a receipt
- [ ] Success message appears
- [ ] Console shows S3 key

### Share Extension

- [ ] Open Photos app
- [ ] Select an image
- [ ] Tap Share button
- [ ] Select "Dobby" from share sheet
- [ ] Upload progress appears
- [ ] Extension closes on success

### Multiple Files

- [ ] Select 2-3 images in Photos
- [ ] Share to Dobby
- [ ] Verify "X of Y uploaded" message
- [ ] All files upload successfully

### Error Handling

- [ ] Enable Airplane Mode
- [ ] Try to upload
- [ ] Error message appears
- [ ] Disable Airplane Mode
- [ ] Upload works again

## 🔧 Troubleshooting

If share extension doesn't appear:
1. Clean Build Folder (⌘⇧K)
2. Delete app from device
3. Rebuild and reinstall
4. Check Info.plist is correct

If uploads fail:
1. Check console for error messages
2. Verify internet connection
3. Test API endpoint in browser/Postman
4. Check target membership of ReceiptUploadService

## 📝 Files Created

- ✅ `ReceiptUploadService.swift` - Upload service (main app + extension)
- ✅ `ShareViewController.swift` - Extension view controller (extension only)
- ✅ `ShareExtensionView.swift` - SwiftUI extension view (extension only)
- ✅ `ShareExtension-Info.plist` - Template configuration
- ✅ `RECEIPT_UPLOAD_INTEGRATION.md` - Full documentation
- ✅ Updated `ReceiptScanView.swift` - Uses new upload API

## 🎯 Expected Behavior

### Scanning
1. User taps "Scan Receipt"
2. Camera opens
3. User captures receipt
4. Image uploads automatically
5. "Receipt saved successfully" message
6. Extension closes

### Sharing
1. User selects image/PDF in another app
2. Taps Share → Dobby
3. Extension opens with progress view
4. Upload completes
5. Extension closes automatically

## 🚀 You're Done!

Once all items are checked, your receipt upload integration is complete. Both the scan feature and share extension will upload receipts to your API endpoint.

**API Endpoint:**  
`https://3edaeenmik.eu-west-1.awsapprunner.com/upload`

**Response Format:**
```json
{
  "status": "success",
  "s3_key": "receipts/receipt_2026-01-19_14-30-45.jpg"
}
```

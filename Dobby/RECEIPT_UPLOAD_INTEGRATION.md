# Receipt Upload Integration Guide

This guide explains how to integrate the receipt upload API into your Dobby app for both the scan feature and the share extension.

## Overview

All receipt files uploaded in the app now use the following API endpoint:
```
POST https://3edaeenmik.eu-west-1.awsapprunner.com/upload
```

**API Response:**
```json
{
  "status": "success",
  "s3_key": "receipts/test.pdf"
}
```

## Files Created

### 1. ReceiptUploadService.swift
A reusable service that handles all receipt uploads. This file should be added to **both** your main app target and share extension target.

**Features:**
- Uploads images directly from `UIImage`
- Uploads files from file URLs
- Supports multiple file types (JPEG, PNG, PDF)
- Uses multipart/form-data encoding
- Proper error handling with custom error types
- Thread-safe actor implementation

### 2. ShareExtensionView.swift
The SwiftUI view for the share extension that handles receipt uploads from Photos, Files, or other apps.

**Features:**
- Supports multiple file uploads (up to 10 images/files)
- Progress tracking with visual feedback
- Handles images, PDFs, and other files
- Clean error handling with user-friendly messages
- Automatic file type detection

### 3. ShareViewController.swift
The UIKit bridge that hosts the SwiftUI share extension view.

### 4. ShareExtension-Info.plist
Template configuration for your share extension that allows sharing images and files.

## Setup Instructions

### Step 1: Add ReceiptUploadService to Your Targets

1. In Xcode, find `ReceiptUploadService.swift` in the project navigator
2. Open the **File Inspector** (⌥⌘1)
3. Under **Target Membership**, check:
   - ✅ Dobby (main app)
   - ✅ Dobby Share Extension

### Step 2: Set Up Share Extension Target

If you don't already have a share extension:

1. **File → New → Target**
2. Select **Share Extension**
3. Name it "Dobby Share Extension"
4. Click **Finish**
5. **Delete** the default files:
   - `ShareViewController.swift` (the default one)
   - `MainInterface.storyboard`

### Step 3: Add Share Extension Files

1. Add `ShareViewController.swift` to the share extension target only
2. Add `ShareExtensionView.swift` to the share extension target only
3. Make sure `ReceiptUploadService.swift` is in **both** targets

### Step 4: Configure Info.plist for Share Extension

1. Open your share extension's `Info.plist`
2. Right-click → **Open As → Source Code**
3. Replace the `<key>NSExtension</key>` section with the content from `ShareExtension-Info.plist`

**This configuration allows:**
- Up to 10 images
- Up to 10 files (PDFs, documents, etc.)

### Step 5: Configure App Groups (Optional but Recommended)

If you want to share data between your main app and share extension:

**Main App:**
1. Select project → **Dobby target** → **Signing & Capabilities**
2. **+ Capability** → **App Groups**
3. Add: `group.com.yourcompany.dobby` (use your actual bundle ID prefix)

**Share Extension:**
1. Select project → **Dobby Share Extension target** → **Signing & Capabilities**
2. **+ Capability** → **App Groups**
3. Add the **same** group: `group.com.yourcompany.dobby`

### Step 6: Build and Test

1. **Product → Clean Build Folder** (⌘⇧K)
2. **Product → Build** (⌘B)
3. Run the app
4. Test scanning a receipt in the app
5. Test sharing an image/PDF from Photos or Files app

## How It Works

### In-App Scanning

When a user scans a receipt in `ReceiptScanView`:

1. Document scanner captures the image
2. If multiple pages, the best quality image is selected automatically
3. Image is uploaded to the API using `ReceiptUploadService`
4. Optionally saved locally as a backup
5. Success message shown to user

**Updated code in `ReceiptScanView.swift`:**
```swift
let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
print("Receipt uploaded successfully - S3 Key: \(response.s3_key)")
```

### Share Extension

When a user shares from another app:

1. User selects image/PDF in Photos or Files app
2. Taps Share button → selects "Dobby"
3. Share extension opens with `ShareExtensionView`
4. Files are automatically extracted and uploaded
5. Progress shown for each upload
6. Extension closes on completion

**Key features:**
- Handles multiple files in batch
- Shows progress: "2 of 5 uploaded"
- Displays current filename being uploaded
- Error handling with retry option

## API Integration Details

### Request Format

The service sends a multipart/form-data POST request:

```http
POST /upload HTTP/1.1
Host: 3edaeenmik.eu-west-1.awsapprunner.com
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary...

------WebKitFormBoundary...
Content-Disposition: form-data; name="file"; filename="receipt_2026-01-19_14-30-45.jpg"
Content-Type: image/jpeg

<binary data>
------WebKitFormBoundary...--
```

### Response Handling

**Success (HTTP 200):**
```json
{
  "status": "success",
  "s3_key": "receipts/receipt_2026-01-19_14-30-45.jpg"
}
```

**Error handling:**
- Network errors
- Invalid response format
- HTTP status codes outside 200-299
- Server-side errors

## File Naming Convention

All uploaded files use timestamp-based names:
```
receipt_YYYY-MM-DD_HH-MM-SS.ext
```

Example: `receipt_2026-01-19_14-30-45.jpg`

## Supported File Types

- **Images:** JPEG, PNG (converted to JPEG for optimization)
- **Documents:** PDF
- **Other files:** Supported but sent as `application/octet-stream`

## Error Messages

User-friendly error messages are shown for:
- ❌ Network connection issues
- ❌ Invalid file format
- ❌ Server errors
- ❌ Timeout errors (60 second timeout)

## Testing Checklist

### Main App - Scan Feature
- [ ] Open app → Scan Receipt
- [ ] Scan a single receipt → Should upload successfully
- [ ] Scan multiple pages → Should select best quality and upload
- [ ] Test with poor lighting → Should still work
- [ ] Verify success message appears
- [ ] Check console for S3 key in response

### Share Extension
- [ ] Open Photos app → Select an image
- [ ] Tap Share → Select "Dobby"
- [ ] Verify upload progress shown
- [ ] Verify success and extension closes
- [ ] Test with multiple images (select 2-3)
- [ ] Test with a PDF from Files app
- [ ] Test canceling mid-upload

### Error Scenarios
- [ ] Turn on Airplane Mode → Try to upload → Should show error
- [ ] Upload very large file → Should timeout gracefully
- [ ] Cancel during upload → Should close cleanly

## Troubleshooting

### Share Extension Not Appearing

1. Make sure Info.plist is configured correctly
2. Check Target Membership for all files
3. Clean build folder and rebuild
4. Delete app from device/simulator and reinstall

### Uploads Failing

1. Check internet connection
2. Verify API endpoint is correct
3. Check console logs for detailed error messages
4. Ensure file size is reasonable (< 10MB recommended)

### Share Extension Crashes

1. Verify `ReceiptUploadService.swift` is in share extension target
2. Check that all imports are available in extension
3. Look for missing frameworks in extension target

## Advanced Configuration

### Adjusting Upload Limits

In `ShareExtension-Info.plist`, you can adjust:

```xml
<!-- Max number of images that can be shared at once -->
<key>NSExtensionActivationSupportsImageWithMaxCount</key>
<integer>10</integer>

<!-- Max number of files that can be shared at once -->
<key>NSExtensionActivationSupportsFileWithMaxCount</key>
<integer>10</integer>
```

### Adding URL Support

To allow sharing URLs (for web-based receipts):

```xml
<key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
<integer>1</integer>
```

### Custom Compression Quality

In `ReceiptUploadService.swift`, adjust JPEG quality:

```swift
// Current: 0.9 (high quality, larger file)
guard let imageData = image.jpegData(compressionQuality: 0.9) else {

// For smaller files: 0.7-0.8
guard let imageData = image.jpegData(compressionQuality: 0.8) else {
```

## Security Considerations

1. **HTTPS:** All uploads use HTTPS for encryption
2. **Timeout:** 60 second timeout prevents hanging requests
3. **File validation:** Only expected file types are uploaded
4. **Error handling:** Sensitive error details not shown to users

## Next Steps

Consider adding:
- [ ] Local caching for offline uploads
- [ ] Background upload queue
- [ ] Receipt metadata (date, amount) in upload
- [ ] OCR processing before upload
- [ ] Thumbnail generation
- [ ] Upload history tracking
- [ ] Retry mechanism for failed uploads

## Support

If you encounter issues:

1. Check Xcode console for error logs
2. Verify API endpoint is accessible
3. Test with a simple image first
4. Ensure all targets are properly configured

---

**Created:** January 19, 2026  
**Last Updated:** January 19, 2026

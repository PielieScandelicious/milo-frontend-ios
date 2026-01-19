# Migration Guide: Local Storage → Cloud API

This guide helps you understand the changes made to migrate from local file storage to cloud-based receipt uploads.

## Overview

**Before:** Receipts were saved to the app's Documents directory  
**After:** Receipts are uploaded to your AWS S3 bucket via API endpoint

## What Changed

### ReceiptScanView.swift

#### Before (Local Storage)
```swift
private func processReceipt(image: UIImage) {
    Task {
        do {
            // Save image to receipts directory
            let savedURL = try saveReceiptImage(image)
            print("Receipt saved successfully to: \(savedURL.path)")
            
            // Show success
            showSuccessMessage = true
        } catch {
            errorMessage = "Failed to save receipt: \(error.localizedDescription)"
            showError = true
        }
    }
}

private func saveReceiptImage(_ image: UIImage) throws -> URL {
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        throw ReceiptError.directoryNotFound
    }
    
    let receiptsDirectory = documentsDirectory.appendingPathComponent("receipts", isDirectory: true)
    
    if !fileManager.fileExists(atPath: receiptsDirectory.path) {
        try fileManager.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
    }
    
    let filename = "receipt_\(timestamp).jpg"
    let fileURL = receiptsDirectory.appendingPathComponent(filename)
    
    guard let imageData = image.jpegData(compressionQuality: 0.9) else {
        throw ReceiptError.imageConversionFailed
    }
    
    try imageData.write(to: fileURL)
    return fileURL
}
```

#### After (Cloud Upload)
```swift
private func processReceipt(image: UIImage) {
    Task {
        do {
            // Upload receipt to server
            print("Uploading receipt to server...")
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            print("Receipt uploaded successfully - S3 Key: \(response.s3_key)")
            
            // Optionally save locally as backup
            let savedURL = try? saveReceiptImage(image)
            if let savedURL = savedURL {
                print("Receipt also saved locally to: \(savedURL.path)")
            }
            
            // Show success
            showSuccessMessage = true
        } catch {
            errorMessage = "Failed to upload receipt: \(error.localizedDescription)"
            showError = true
        }
    }
}
```

### New Files Added

1. **ReceiptUploadService.swift** - New upload service
2. **ShareExtensionView.swift** - Share extension UI
3. **ShareViewController.swift** - Share extension bridge

### Files Kept (Optional Backup)

The local `saveReceiptImage()` method is still in `ReceiptScanView.swift` but now optional:

```swift
// Optionally save locally as backup
let savedURL = try? saveReceiptImage(image)
```

You can:
- **Keep it** for offline backup and sync later
- **Remove it** if you only want cloud storage

## Benefits of Migration

### 1. Cloud Storage
- ✅ Receipts accessible from anywhere
- ✅ Not limited by device storage
- ✅ Automatic backup
- ✅ Survives app deletion

### 2. Sync Capability
- ✅ Access receipts on multiple devices
- ✅ Web dashboard possible
- ✅ Share receipts easily
- ✅ Integration with other services

### 3. Processing
- ✅ Server-side OCR possible
- ✅ Image optimization on server
- ✅ Metadata extraction
- ✅ Analytics and reporting

### 4. Security
- ✅ Professional backup solution
- ✅ Encrypted transfer (HTTPS)
- ✅ Access control via API
- ✅ Audit trail

## Backward Compatibility

### Local Files Still Work

The `saveReceiptImage()` method is still available, so:

```swift
// You can still access locally saved receipts
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
let receiptsDirectory = documentsDirectory?.appendingPathComponent("receipts")

if let receiptsDirectory = receiptsDirectory {
    let receipts = try? FileManager.default.contentsOfDirectory(at: receiptsDirectory, includingPropertiesForKeys: nil)
    // receipts contains all locally saved receipt files
}
```

### Migration Strategy

If you have existing local receipts you want to upload:

```swift
func migrateLocalReceipts() async {
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
    }
    
    let receiptsDirectory = documentsDirectory.appendingPathComponent("receipts")
    
    guard let receipts = try? fileManager.contentsOfDirectory(
        at: receiptsDirectory,
        includingPropertiesForKeys: nil
    ) else {
        return
    }
    
    for receiptURL in receipts {
        do {
            // Upload each local receipt
            let response = try await ReceiptUploadService.shared.uploadReceipt(from: receiptURL)
            print("Migrated: \(receiptURL.lastPathComponent) → \(response.s3_key)")
            
            // Optionally delete local file after successful upload
            try? fileManager.removeItem(at: receiptURL)
        } catch {
            print("Failed to migrate \(receiptURL.lastPathComponent): \(error)")
        }
    }
}
```

## Hybrid Approach (Recommended)

Keep both local and cloud storage for redundancy:

```swift
private func processReceipt(image: UIImage) {
    Task {
        var cloudUploadSuccess = false
        var localSaveSuccess = false
        
        // Try cloud upload first
        do {
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            print("✅ Cloud upload successful: \(response.s3_key)")
            cloudUploadSuccess = true
        } catch {
            print("❌ Cloud upload failed: \(error)")
        }
        
        // Always save locally as backup
        do {
            let savedURL = try saveReceiptImage(image)
            print("✅ Local save successful: \(savedURL.path)")
            localSaveSuccess = true
        } catch {
            print("❌ Local save failed: \(error)")
        }
        
        // Show appropriate message
        if cloudUploadSuccess {
            showSuccessMessage = true
        } else if localSaveSuccess {
            showSuccessMessage = true // Saved locally, will sync later
        } else {
            errorMessage = "Failed to save receipt"
            showError = true
        }
    }
}
```

## Offline Support

If you want to support offline uploads:

```swift
// Queue failed uploads for later
struct PendingUpload: Codable {
    let localURL: URL
    let timestamp: Date
}

class UploadQueue {
    private let queueKey = "pendingUploads"
    
    func addToQueue(localURL: URL) {
        var queue = getQueue()
        queue.append(PendingUpload(localURL: localURL, timestamp: Date()))
        saveQueue(queue)
    }
    
    func processQueue() async {
        let queue = getQueue()
        
        for pending in queue {
            do {
                let response = try await ReceiptUploadService.shared.uploadReceipt(from: pending.localURL)
                print("Queued upload successful: \(response.s3_key)")
                removeFromQueue(pending)
            } catch {
                print("Queued upload still failing: \(error)")
            }
        }
    }
    
    private func getQueue() -> [PendingUpload] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([PendingUpload].self, from: data) else {
            return []
        }
        return queue
    }
    
    private func saveQueue(_ queue: [PendingUpload]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
    
    private func removeFromQueue(_ pending: PendingUpload) {
        var queue = getQueue()
        queue.removeAll { $0.localURL == pending.localURL }
        saveQueue(queue)
    }
}
```

Usage:

```swift
let uploadQueue = UploadQueue()

private func processReceipt(image: UIImage) {
    Task {
        do {
            // Try cloud upload
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            print("✅ Uploaded: \(response.s3_key)")
        } catch {
            // Save locally and queue for later
            if let savedURL = try? saveReceiptImage(image) {
                uploadQueue.addToQueue(localURL: savedURL)
                print("⏳ Queued for upload when online")
            }
        }
    }
}

// In your app delegate or scene delegate
func applicationDidBecomeActive(_ application: UIApplication) {
    Task {
        await uploadQueue.processQueue()
    }
}
```

## Cleanup Recommendations

### Remove Local Storage Completely (Option 1)

If you only want cloud storage:

1. Remove `saveReceiptImage()` method from `ReceiptScanView.swift`
2. Remove `ReceiptError` enum (if only used for local storage)
3. Remove local backup code from `processReceipt()`

### Keep Local Backup (Option 2)

Keep current implementation with both cloud and local storage.

### Hybrid with Queue (Option 3)

Implement the offline queue system above for best of both worlds.

## Testing Your Migration

### Test Cloud Upload
```swift
@Test("Receipt uploads to cloud")
func testCloudUpload() async throws {
    let testImage = UIImage(systemName: "photo")!
    let response = try await ReceiptUploadService.shared.uploadReceipt(image: testImage)
    #expect(response.status == "success")
}
```

### Test Local Backup
```swift
@Test("Receipt saves locally as backup")
func testLocalBackup() throws {
    let testImage = UIImage(systemName: "photo")!
    let view = ReceiptScanView()
    let savedURL = try view.saveReceiptImage(testImage)
    #expect(FileManager.default.fileExists(atPath: savedURL.path))
}
```

### Test Offline Behavior
```swift
@Test("Receipt queues when offline")
func testOfflineQueue() async throws {
    // Simulate offline by using invalid URL
    // Verify receipt is saved locally
    // Verify it's added to queue
}
```

## Rollback Plan

If you need to rollback to local-only storage:

1. Comment out cloud upload code
2. Remove `try?` from `saveReceiptImage()` call
3. Make it throw errors again
4. Rebuild and deploy

Original code preserved in this migration guide for reference.

## Summary

### What You Gain
- ✅ Cloud storage with unlimited space
- ✅ Multi-device sync capability  
- ✅ Professional backup solution
- ✅ Server-side processing options
- ✅ Share extension support

### What You Keep
- ✅ Local backup option (if desired)
- ✅ Offline functionality (with queue)
- ✅ Same user experience
- ✅ Existing local files still work

### What You Lose
- ❌ Fully offline operation (without local backup)
- ❌ No network = no upload (without queue)
- ❌ Dependent on API uptime

### Recommendation
Use the **hybrid approach** with offline queue for best user experience and reliability.

---

**Migration completed:** January 19, 2026  
**Questions?** Check `RECEIPT_UPLOAD_INTEGRATION.md` for full documentation

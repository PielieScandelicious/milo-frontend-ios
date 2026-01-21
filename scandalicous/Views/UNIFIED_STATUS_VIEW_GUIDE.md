# Unified Receipt Status View - Migration Guide

## Overview

The receipt upload UI has been simplified to use a **single, consistent message box** that updates its content for all states (uploading, processing, success, failure) instead of showing multiple different pop-ups.

## New Component: `ReceiptStatusView`

### States

```swift
enum ReceiptStatusType {
    case uploading(subtitle: String)          // Shows progress spinner
    case processing(subtitle: String)         // Shows progress spinner
    case success(message: String)             // Shows green checkmark
    case failed(message: String, canRetry: Bool) // Shows red X with optional retry
}
```

### Key Changes

1. **One Box, Multiple States**: The same box updates to show uploading → processing → success/failed
2. **No Server Error Details**: Generic user-friendly messages only (no technical details)
3. **Consistent Design**: Matches the "Uploading receipt..." style throughout
4. **Auto-hiding for Success**: Success states can auto-dismiss after showing briefly

## Migration Examples

### Before (Multiple Separate Overlays)

```swift
// OLD: Multiple different overlays
if case .uploading = uploadState {
    uploadingOverlay()
}

if case .processing = uploadState {
    processingOverlay()
}

.receiptErrorOverlay(
    isPresented: $showError,
    message: errorMessage
)
```

### After (One Unified Status View)

```swift
// NEW: One status that changes
@State private var receiptStatus: ReceiptStatusType? = nil

var body: some View {
    YourContent()
        .receiptStatusOverlay(
            status: $receiptStatus,
            onRetry: {
                receiptStatus = nil
                retryUpload()
            },
            onDismiss: {
                receiptStatus = nil
            }
        )
}

// Update the status as needed:
receiptStatus = .uploading(subtitle: "Sending to server...")
receiptStatus = .processing(subtitle: "Extracting items...")
receiptStatus = .success(message: "Receipt uploaded!")
receiptStatus = .failed(message: "Please try again.", canRetry: true)
```

## User-Friendly Error Messages

### ❌ Don't Show Technical Details

```swift
// BAD: Shows technical server error
.failed(message: "Server returned status code 500: Internal server error", canRetry: true)

// BAD: Shows network implementation details  
.failed(message: "URLSession failed with error: The network connection was lost", canRetry: true)
```

### ✅ Show Simple, Actionable Messages

```swift
// GOOD: Simple, user-friendly
.failed(message: "Please check your internet connection and try again.", canRetry: true)

// GOOD: Clear and actionable
.failed(message: "Unable to upload receipt. Please try again later.", canRetry: true)

// GOOD: Specific but friendly
.failed(message: "This file type is not supported.", canRetry: false)
```

## Complete Upload Flow Example

```swift
struct ReceiptUploadView: View {
    @State private var receiptStatus: ReceiptStatusType? = nil
    @State private var capturedImage: UIImage?
    
    var body: some View {
        YourContent()
            .receiptStatusOverlay(
                status: $receiptStatus,
                onRetry: {
                    if let image = capturedImage {
                        Task {
                            receiptStatus = nil
                            try? await Task.sleep(for: .milliseconds(300))
                            await uploadReceipt(image)
                        }
                    }
                },
                onDismiss: {
                    receiptStatus = nil
                }
            )
    }
    
    func uploadReceipt(_ image: UIImage) async {
        // 1. Show uploading
        receiptStatus = .uploading(subtitle: "Sending to Claude Vision API")
        
        do {
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            
            // 2. Show processing (if needed)
            if response.status == .processing {
                receiptStatus = .processing(subtitle: "Extracting items and prices")
                // Could poll for completion here
            }
            
            // 3. Show success
            receiptStatus = .success(message: "Receipt uploaded successfully!")
            
            // 4. Auto-dismiss success after delay
            try? await Task.sleep(for: .seconds(1.5))
            receiptStatus = nil
            
        } catch {
            // 5. Show error with user-friendly message
            receiptStatus = .failed(
                message: "Please check your internet connection and try again.",
                canRetry: true
            )
        }
    }
}
```

## Share Extension (UIKit)

```swift
class ShareViewController: UIViewController {
    private var statusVC: ReceiptStatusViewController?
    
    func uploadReceipt() async {
        // Show uploading
        showStatus(.uploading(subtitle: "Sending to server..."))
        
        do {
            let response = try await upload()
            
            // Update to processing
            updateStatus(.processing(subtitle: "Extracting items..."))
            
            // Show success
            updateStatus(.success(message: "Receipt uploaded!"))
            
            // Auto-dismiss after delay
            try? await Task.sleep(for: .seconds(1.5))
            extensionContext?.completeRequest(returningItems: nil)
            
        } catch {
            // Show error
            updateStatus(.failed(
                message: "Please try again.",
                canRetry: false
            ))
        }
    }
    
    private func showStatus(_ status: ReceiptStatusType) {
        let vc = ReceiptStatusViewController(
            status: status,
            onRetry: nil,
            onDismiss: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: NSError(...))
            }
        )
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true)
        statusVC = vc
    }
    
    private func updateStatus(_ newStatus: ReceiptStatusType) {
        statusVC?.updateStatus(newStatus)
    }
}
```

## Error Message Guidelines

### Network Errors
- ✅ "Please check your internet connection and try again."
- ❌ "URLSession error: -1009"

### Server Errors
- ✅ "Unable to upload receipt. Please try again later."
- ❌ "Server returned HTTP 500"

### Quality Errors
- ✅ "Image quality is too low. Please ensure good lighting and try again."
- ❌ "Quality score 0.42 below threshold 0.6"

### File Type Errors
- ✅ "This file type is not supported."
- ❌ "MIME type application/heic not in allowed types array"

### Auth Errors
- ✅ "Please sign in again."
- ❌ "Firebase Auth token expired (error code: auth/token-expired)"

## Benefits

1. **Cleaner UX**: One box that smoothly transitions between states
2. **Less Jarring**: No multiple pop-ups appearing and disappearing
3. **Consistent**: Same design for all upload phases
4. **User-Friendly**: Simple messages without technical jargon
5. **Professional**: Matches modern app design patterns

## Backward Compatibility

The old `ReceiptErrorView` still works for backward compatibility:

```swift
// Old API still works
.receiptErrorOverlay(
    isPresented: $showError,
    message: errorMessage,
    onRetry: { ... }
)
```

But the new unified approach is recommended for new code!

## Next Steps

1. Replace separate uploading/processing overlays with unified status view
2. Update error messages to be user-friendly (remove technical details)
3. Use the same box for all upload states
4. Test the smooth transitions between states
5. Consider auto-dismissing success states after 1-2 seconds

---

**Result**: Users see one consistent, beautiful message box that updates smoothly through the entire upload process! 🎉

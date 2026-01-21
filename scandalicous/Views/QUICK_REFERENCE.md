# Receipt Error UI - Quick Reference Card

## 🚀 Quick Start

### SwiftUI (Most Common)

```swift
struct YourView: View {
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        YourContent()
            .receiptErrorOverlay(
                isPresented: $showError,
                message: errorMessage,
                onRetry: {
                    // Retry logic (optional)
                }
            )
    }
}
```

### UIKit (Share Extension)

```swift
let errorVC = ReceiptErrorViewController(
    title: "Processing Failed!",
    message: error.localizedDescription,
    onRetry: nil, // or { /* retry */ }
    onDismiss: { [weak self] in
        self?.dismiss(animated: true)
    }
)

errorVC.modalPresentationStyle = .overFullScreen
present(errorVC, animated: true)
```

## 🎯 Common Patterns

### Pattern 1: Quality Check Error

```swift
errorMessage = """
Receipt quality too low for accurate processing.

Issues detected:
• Image is too blurry
• Poor lighting conditions

Tips:
• Ensure good lighting
• Hold device steady
• Capture entire receipt
"""
showError = true
```

### Pattern 2: Network Error

```swift
errorMessage = "Failed to upload receipt. Please check your internet connection and try again."
canRetryAfterError = true
showError = true
```

### Pattern 3: Server Error

```swift
errorMessage = "The receipt could not be processed by the server. Please try again."
canRetryAfterError = true
showError = true
```

### Pattern 4: Unsupported Type

```swift
errorMessage = "Unsupported file type: .\(fileExtension)"
canRetryAfterError = false
showError = true
```

## 🎨 Customization Options

### Title
```swift
// Default
title: "Processing Failed!"

// Custom
title: "Quality Check Failed"
title: "Upload Failed"
title: "Network Error"
```

### Message
```swift
// Simple
message: "Please try again."

// Detailed
message: """
Multiple issues detected:
• Issue 1
• Issue 2

Tips:
• Tip 1
• Tip 2
"""
```

### Retry
```swift
// With retry
onRetry: {
    // Show scanner again
    showDocumentScanner = true
}

// Without retry
onRetry: nil
```

## 🔧 Integration Checklist

- [ ] Import error view if needed
- [ ] Add `@State var showError = false`
- [ ] Add `@State var errorMessage = ""`
- [ ] Add `.receiptErrorOverlay()` modifier
- [ ] Set `errorMessage` in catch blocks
- [ ] Set `showError = true` on error
- [ ] Implement retry logic (if applicable)
- [ ] Test all error scenarios

## 📋 Error Types

| Error Type | Retry? | Example Message |
|------------|--------|-----------------|
| Quality | ✅ Yes | "Receipt quality too low..." |
| Network | ✅ Yes | "Please check your connection..." |
| Server | ✅ Yes | "Server could not process..." |
| Auth | ✅ Yes | "Authentication failed..." |
| Unsupported | ❌ No | "Unsupported file type..." |
| No Content | ❌ No | "No content found..." |

## 🎭 States

```swift
// Idle (no error)
showError = false

// Error shown
showError = true
errorMessage = "Your error message"

// After retry
showError = false
errorMessage = ""
// ... trigger retry logic

// After dismiss  
showError = false
errorMessage = ""
```

## 💡 Best Practices

### ✅ Do
- Use clear, actionable messages
- Provide retry when possible
- Include tips for user errors
- Show relevant error details
- Reset state after dismiss/retry

### ❌ Don't
- Show generic "Error" messages
- Use technical jargon
- Blame the user
- Leave state dirty
- Forget haptic feedback

## 🐛 Common Issues

### Issue: Error won't show
```swift
// ❌ Wrong
.receiptErrorOverlay(isPresented: .constant(true), ...)

// ✅ Correct
.receiptErrorOverlay(isPresented: $showError, ...)
```

### Issue: Multiple errors stack
```swift
// ✅ Solution: Reset before showing new error
showError = false
errorMessage = ""
// Small delay if needed
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    errorMessage = newError
    showError = true
}
```

### Issue: Retry doesn't work
```swift
// ✅ Solution: Ensure retry action is provided
.receiptErrorOverlay(
    isPresented: $showError,
    message: errorMessage,
    onRetry: { // ← Don't forget this!
        retryUpload()
    }
)
```

## 📱 Testing

### Test Scenarios
1. Show error without retry
2. Show error with retry
3. Tap retry button
4. Tap dismiss button
5. Tap outside to dismiss (SwiftUI)
6. Long error message
7. Multiple errors in sequence
8. Dark mode appearance
9. Landscape orientation
10. VoiceOver enabled

### Quick Test
```swift
// Add to your view for testing
#if DEBUG
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        errorMessage = "Test error message"
        showError = true
    }
}
#endif
```

## 📞 Need Help?

- **Documentation**: See `RECEIPT_ERROR_HANDLING.md`
- **Examples**: See `IMPLEMENTATION_SUMMARY.md`
- **Design**: See `ERROR_UI_VISUAL_REFERENCE.md`
- **Checklist**: See `IMPLEMENTATION_CHECKLIST.md`

---

## 🎯 Copy-Paste Templates

### Template 1: Simple Error
```swift
do {
    try await uploadReceipt()
} catch {
    errorMessage = error.localizedDescription
    showError = true
}
```

### Template 2: Error with Retry
```swift
do {
    try await uploadReceipt()
} catch {
    errorMessage = "Failed to upload: \(error.localizedDescription)"
    canRetryAfterError = true
    showError = true
}
```

### Template 3: Quality Error
```swift
guard qualityResult.isAcceptable else {
    errorMessage = """
    Quality too low: \(Int(qualityResult.qualityScore * 100))%
    
    Issues:
    \(qualityResult.issues.map { "• \($0)" }.joined(separator: "\n"))
    """
    canRetryAfterError = true
    showError = true
    return
}
```

---

**Keep this card handy for quick reference!** 📌

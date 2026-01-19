# Advanced Share Extension Tips

## Making the Experience Even More Seamless

### 1. Open Main App After Sharing (Optional)

If you want users to be automatically taken to your main app after sharing, you can use URL schemes:

```swift
// Add this method to ShareViewController.swift
private func openMainApp() {
    guard let url = URL(string: "dobby://receipts/new") else { return }
    
    var responder: UIResponder? = self as UIResponder
    let selector = #selector(openURL(_:))
    
    while responder != nil {
        if responder!.responds(to: selector) && responder != self {
            responder!.perform(selector, with: url)
            return
        }
        responder = responder?.next
    }
}

@objc private func openURL(_ url: URL) {
    // This will be called by the system
}

// Call it before completing:
private func saveReceiptImage(_ image: UIImage) async {
    // ... existing code ...
    
    updateStatus(success: "Receipt saved successfully!")
    
    // Open main app
    openMainApp()
    
    try? await Task.sleep(nanoseconds: 800_000_000) // Shorter since we're opening app
    await animateDismissal()
    completeRequest(withError: nil)
}
```

**Important**: You'll also need to:
1. Add URL scheme to your main app's Info.plist
2. Handle the URL in your main app to show the new receipt

### 2. Live Activity / Dynamic Island (iOS 16.1+)

For a truly premium experience, show a Live Activity while processing:

```swift
import ActivityKit

@available(iOS 16.1, *)
private func startReceiptActivity() {
    let attributes = ReceiptActivityAttributes(receiptCount: 1)
    let state = ReceiptActivityAttributes.ContentState(
        status: "Saving receipt...",
        progress: 0.0
    )
    
    do {
        let activity = try Activity<ReceiptActivityAttributes>.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
        )
        
        // Update progress as needed
    } catch {
        print("Failed to start activity: \(error)")
    }
}
```

This would show your receipt processing in the Dynamic Island!

### 3. Reduce Motion Support

For users with "Reduce Motion" enabled, provide alternative animations:

```swift
private var shouldReduceMotion: Bool {
    UIAccessibility.isReduceMotionEnabled
}

private func animateIn() {
    if shouldReduceMotion {
        // Simple fade, no spring
        UIView.animate(withDuration: 0.2) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            self.containerView.alpha = 1
        }
    } else {
        // Full spring animation
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
    }
}
```

### 4. Smart Timing Based on Image Size

Adjust display time based on how long processing actually takes:

```swift
private func saveReceiptImage(_ image: UIImage) async {
    let startTime = Date()
    
    do {
        await showImagePreview(image)
        updateStatus(message: "Saving receipt...")
        
        let savedPath = try saveReceipt(image: image)
        notifyMainApp(imagePath: savedPath)
        
        // Calculate how long it actually took
        let processingTime = Date().timeIntervalSince(startTime)
        
        updateStatus(success: "Receipt saved successfully!")
        
        // If processing was super fast, show success longer
        // If it took a while, dismiss sooner
        let successDisplayTime = min(1.5, max(0.8, 2.0 - processingTime))
        let nanoseconds = UInt64(successDisplayTime * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        
        await animateDismissal()
        completeRequest(withError: nil)
        
    } catch {
        // Handle error...
    }
}
```

### 5. Batch Processing with Progress

If users share multiple images, show progress:

```swift
private let progressView: UIProgressView = {
    let progress = UIProgressView(progressViewStyle: .default)
    progress.translatesAutoresizingMaskIntoConstraints = false
    progress.alpha = 0
    return progress
}()

private func processMultipleImages(_ images: [UIImage]) async {
    showProgressBar()
    
    for (index, image) in images.enumerated() {
        updateProgress(current: index + 1, total: images.count)
        try? await saveReceipt(image: image)
    }
    
    hideProgressBar()
    updateStatus(success: "Saved \(images.count) receipts!")
}

private func updateProgress(current: Int, total: Int) {
    DispatchQueue.main.async {
        let progress = Float(current) / Float(total)
        self.progressView.setProgress(progress, animated: true)
        self.storeLabel.text = "Saving \(current) of \(total)..."
    }
}
```

### 6. Error Recovery Options

Give users options when something goes wrong:

```swift
private func updateStatus(error: String, canRetry: Bool = false) {
    DispatchQueue.main.async {
        // Haptic feedback for error
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        self.titleLabel.text = "Error"
        self.statusLabel.text = error
        self.statusLabel.textColor = .systemRed
        self.activityIndicator.stopAnimating()
        
        if canRetry {
            self.addRetryButton()
        }
    }
}

private func addRetryButton() {
    let retryButton = UIButton(type: .system)
    retryButton.setTitle("Try Again", for: .normal)
    retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    // ... add to container and layout
}

@objc private func retryTapped() {
    // Reset UI and try again
    processSharedContent()
}
```

### 7. Smart Defaults with UserDefaults

Remember user preferences:

```swift
private enum SharePreference: String {
    case autoOpenApp = "share_auto_open_app"
    case showPreview = "share_show_preview"
    case hapticFeedback = "share_haptic_feedback"
}

private var shouldAutoOpenApp: Bool {
    UserDefaults.standard.bool(forKey: SharePreference.autoOpenApp.rawValue)
}

private var shouldShowPreview: Bool {
    UserDefaults.standard.object(forKey: SharePreference.showPreview.rawValue) as? Bool ?? true
}

// In main app settings:
Toggle("Open app after sharing", isOn: $autoOpenApp)
Toggle("Show receipt preview", isOn: $showPreview)
Toggle("Haptic feedback", isOn: $hapticFeedback)
```

### 8. Network-Aware Behavior

If you sync to cloud, check network before starting:

```swift
import Network

private let monitor = NWPathMonitor()

private func checkNetworkAndSave() {
    monitor.pathUpdateHandler = { path in
        if path.status == .satisfied {
            // Network available - can sync to cloud
            self.updateStatus(message: "Saving and syncing...")
        } else {
            // No network - save locally
            self.updateStatus(message: "Saving locally...")
        }
    }
    
    let queue = DispatchQueue(label: "NetworkMonitor")
    monitor.start(queue: queue)
}
```

### 9. Share Extension Icon

Make your extension stand out in the share sheet:

1. Add a custom icon in your Share Extension target
2. Set it in Info.plist:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <!-- ... existing rules ... -->
        
        <!-- Add custom icon -->
        <key>PHSupportedMediaTypes</key>
        <array>
            <string>Image</string>
        </array>
    </dict>
    
    <!-- Custom extension icon (optional) -->
    <key>CFBundleIcons</key>
    <dict>
        <key>CFBundlePrimaryIcon</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>ShareExtensionIcon</string>
            </array>
        </dict>
    </dict>
</dict>
```

### 10. Logging for Debugging

Add comprehensive logging to diagnose issues:

```swift
import os.log

private let logger = Logger(subsystem: "com.dobby.shareextension", category: "ShareViewController")

private func saveReceiptImage(_ image: UIImage) async {
    logger.info("Starting receipt save process")
    logger.debug("Image size: \(image.size.width)x\(image.size.height)")
    
    do {
        let startTime = Date()
        let savedPath = try saveReceipt(image: image)
        let duration = Date().timeIntervalSince(startTime)
        
        logger.info("Receipt saved successfully in \(duration)s at \(savedPath)")
        
    } catch {
        logger.error("Failed to save receipt: \(error.localizedDescription)")
    }
}

// View logs in Console app on Mac with: "subsystem:com.dobby.shareextension"
```

## Performance Optimizations

### 1. Lazy Image Loading

Don't load the full resolution for preview:

```swift
private func showImagePreview(_ image: UIImage) async {
    // Create thumbnail for preview
    let size = CGSize(width: 160, height: 160)
    let format = UIGraphicsImageRendererFormat()
    format.scale = UIScreen.main.scale
    
    let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
    
    await MainActor.run {
        imagePreview.image = thumbnail
        // ... animation code
    }
}
```

### 2. Background Processing

Use background tasks for heavy operations:

```swift
private func saveReceiptImage(_ image: UIImage) async {
    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    backgroundTaskID = UIApplication.shared.beginBackgroundTask {
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    
    defer {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
    }
    
    // Do heavy work here...
    let savedPath = try saveReceipt(image: image)
}
```

## Testing Checklist

- [ ] Share from Photos app
- [ ] Share from Safari (save image)
- [ ] Share from Files app
- [ ] Share screenshot from Photos
- [ ] Share PDF (if supported)
- [ ] Share while offline
- [ ] Share with low storage
- [ ] Share in Dark Mode
- [ ] Share with VoiceOver enabled
- [ ] Share with Reduce Motion enabled
- [ ] Share very large image (20+ MB)
- [ ] Share very small image (< 100 KB)
- [ ] Share while device is locked (if applicable)
- [ ] Share from third-party apps

## Common Issues & Solutions

### Issue: Extension crashes immediately
**Solution**: Check Info.plist configuration, ensure NSExtensionPrincipalClass is correct

### Issue: "No content found" error
**Solution**: Verify NSExtensionActivationRule matches the content type you're sharing

### Issue: Files not appearing in main app
**Solution**: Check App Group identifier is identical in both targets

### Issue: Animations stuttering
**Solution**: Ensure all UI updates are on main thread with `@MainActor` or `DispatchQueue.main`

### Issue: Extension takes too long
**Solution**: Move heavy processing to background, show better progress indicators

## Resources

- [App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [Share Extension Best Practices](https://developer.apple.com/documentation/uikit/share_extension)
- [Human Interface Guidelines - Extensions](https://developer.apple.com/design/human-interface-guidelines/extensions)

---

**Pro Tip**: Test your share extension frequently during development. Extensions can be tricky to debug since they run in a separate process!

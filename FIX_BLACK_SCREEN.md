# Fix Black Screen on Physical Device

## Problem
App works in **Simulator** ✅ but shows **black screen on physical device** ❌

## Root Cause
Your Scan tab **automatically opens the camera** when the app launches. On a physical device, iOS **requires camera permission** to be declared in Info.plist. Without it, the app crashes silently (black screen).

## Solution: Add Camera Permission

### Step 1: Open Info.plist

1. In Xcode, find your **main app target** (not the share extension)
2. Find the file called **Info.plist**
3. **Right-click** on Info.plist → **Open As** → **Source Code**

### Step 2: Add Camera Permission

Add this **inside the `<dict>` tag** (before the closing `</dict>`):

```xml
<key>NSCameraUsageDescription</key>
<string>Dobby needs camera access to scan receipts and automatically categorize your expenses</string>
```

### Step 3: Complete Info.plist Structure

Your Info.plist should look like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Your existing keys here -->
    
    <!-- CAMERA PERMISSION (REQUIRED) -->
    <key>NSCameraUsageDescription</key>
    <string>Dobby needs camera access to scan receipts and automatically categorize your expenses</string>
    
    <!-- PHOTO LIBRARY (Optional, for future features) -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Dobby needs access to your photos to import receipt images</string>
    
</dict>
</plist>
```

### Step 4: Clean Build

1. **Product** → **Clean Build Folder** (Cmd + Shift + K)
2. **Delete the app** from your physical device
3. **Rebuild** (Cmd + B)
4. **Run** on your device

## Why This Happens

### Simulator vs Physical Device

| Feature | Simulator | Physical Device |
|---------|-----------|-----------------|
| Camera Access | ✅ Allowed by default | ❌ Requires permission |
| Permission Prompts | ⚠️ Simulated only | ✅ Real iOS prompts |
| Privacy Enforcement | ⚠️ Relaxed | ✅ Strict |
| Info.plist Required | ❌ Optional | ✅ **REQUIRED** |

### What Happens Without Permission

```
1. App launches
2. Scan tab appears
3. onAppear triggers → showCamera = true
4. Camera tries to open
5. iOS checks Info.plist → ❌ NO permission key found
6. iOS KILLS the app instantly
7. User sees black screen
```

## Additional Debugging Steps

### Check Console Output

1. **Window** → **Devices and Simulators**
2. Select your **physical device**
3. Click **Open Console**
4. Run your app
5. Look for errors like:
   ```
   This app has crashed because it attempted to access privacy-sensitive data
   without a usage description. The app's Info.plist must contain an
   NSCameraUsageDescription key with a string value explaining to the user
   how the app uses this data.
   ```

### Test Camera Permission Flow

After adding the permission, the first time you run the app:

1. ✅ App launches successfully
2. ✅ You switch to Scan tab
3. ✅ iOS shows permission alert:
   ```
   "Dobby" Would Like to Access the Camera
   
   Dobby needs camera access to scan receipts and 
   automatically categorize your expenses
   
   [Don't Allow]  [OK]
   ```
4. ✅ Tap **OK**
5. ✅ Camera opens

### Verify Info.plist (Xcode GUI Method)

If you prefer the visual editor:

1. Click **Info.plist**
2. View as **Property List** (default view)
3. Click **+** to add new row
4. Type: `Privacy - Camera Usage Description`
5. Set value: `Dobby needs camera access to scan receipts and automatically categorize your expenses`

## Alternative: Delay Camera Opening

If you want to avoid auto-opening the camera, modify `ReceiptScanView.swift`:

### Option A: Remove Auto-Open
```swift
// Remove this from ReceiptScanView
.onAppear {
    showCamera = true  // ← DELETE THIS
}
```

Then add a button:
```swift
var body: some View {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()
        
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.white)
            
            Text("Ready to Scan")
                .font(.title.bold())
                .foregroundStyle(.white)
            
            Button {
                showCamera = true
            } label: {
                Label("Open Camera", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.blue.gradient)
                    .cornerRadius(12)
            }
        }
    }
    // ... rest of code
}
```

### Option B: Check Permission First

Add permission checking before auto-opening:

```swift
import AVFoundation

.onAppear {
    checkCameraPermission()
}

func checkCameraPermission() {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    
    switch status {
    case .authorized:
        showCamera = true
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.main.async {
                    showCamera = true
                }
            }
        }
    case .denied, .restricted:
        // Show alert to user
        errorMessage = "Camera access is required to scan receipts"
        showError = true
    @unknown default:
        break
    }
}
```

## Required Info.plist Keys for Dobby

Here's a complete list of permissions your app needs:

```xml
<!-- REQUIRED -->
<key>NSCameraUsageDescription</key>
<string>Dobby needs camera access to scan receipts and automatically categorize your expenses</string>

<!-- RECOMMENDED (for future features) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Dobby needs access to your photos to import receipt images</string>

<!-- OPTIONAL (if you add photo saving) -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Dobby can save receipt images to your photo library</string>
```

## Testing Checklist

After adding camera permission:

- [ ] Clean build folder
- [ ] Delete app from device
- [ ] Rebuild and run
- [ ] App opens (no black screen)
- [ ] Permission alert appears when switching to Scan tab
- [ ] Tap "OK" on permission
- [ ] Camera opens successfully
- [ ] Take a photo
- [ ] Processing works
- [ ] Receipt review appears

## Other Possible Causes

If adding camera permission **doesn't fix it**, check:

### 1. Code Signing Issues
- Xcode → Project → Signing & Capabilities
- Ensure "Automatically manage signing" is checked
- Verify your Team is selected
- Check for signing errors in the status bar

### 2. Deployment Target
- Check your deployment target matches your device
- Project Settings → Deployment Info → iOS Deployment Target
- Must be ≤ your device's iOS version

### 3. Required Device Capabilities
Add to Info.plist if needed:
```xml
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>camera-flash</string>
    <string>still-camera</string>
</array>
```

### 4. Background Modes
If you're seeing issues with app lifecycle:
- Add "Background Modes" capability
- Enable "Background fetch" if needed

### 5. App Transport Security
If you're making network calls:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

## Quick Fix Summary

**90% of the time, the fix is:**

1. ✅ Add `NSCameraUsageDescription` to Info.plist
2. ✅ Clean build
3. ✅ Delete app from device
4. ✅ Rebuild and run

**That's it!** 🎉

## Still Not Working?

If you're still seeing a black screen:

1. Check the **device console** for crash logs
2. Look for **red error messages** in Xcode console
3. Verify **code signing** has no issues
4. Try running on a **different physical device**
5. Check if your device's **iOS version is supported**

---

**Most likely solution:** Add camera permission to Info.plist and you're done! ✨

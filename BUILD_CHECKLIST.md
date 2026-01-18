# Pre-Build Checklist for Dobby App

## ✅ Files Added to Xcode Target

Make sure these files are included in your Xcode project target:

### New Files (Must be added to target)
- [ ] env.swift
- [ ] AnthropicService.swift
- [ ] ReceiptImportService.swift
- [ ] ReceiptScanView.swift
- [ ] ReceiptReviewView.swift

### Updated Files (Should already be in target)
- [ ] TransactionModel.swift
- [ ] StoreBreakdownModel.swift
- [ ] ContentView.swift
- [ ] OverviewView.swift

### Documentation Files (NOT added to target)
- [ ] SETUP_GUIDE.md
- [ ] TEST_RECEIPTS.md
- [ ] IMPLEMENTATION_SUMMARY.md
- [ ] README.md
- [ ] Info-additions.plist (reference only)
- [ ] BUILD_CHECKLIST.md (this file)

## ✅ Info.plist Configuration

Add these keys to your Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>Dobby needs access to your camera to scan receipts and automatically categorize your purchases.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Dobby needs access to your photo library to import receipt images for automatic categorization.</string>
```

**How to add:**
1. Open Info.plist in Xcode
2. Right-click → Add Row
3. Add "Privacy - Camera Usage Description"
4. Add "Privacy - Photo Library Usage Description"
5. Enter the descriptions above

## ✅ Xcode Project Settings

### Signing & Capabilities
- [ ] Development team selected
- [ ] Bundle identifier is unique
- [ ] Automatic signing enabled (or manual certificates configured)

### Build Settings
- [ ] iOS Deployment Target: 17.0 or higher
- [ ] Swift Language Version: Swift 5

### Frameworks
These should be automatically linked:
- [ ] SwiftUI
- [ ] Foundation
- [ ] Vision
- [ ] UIKit

## ✅ API Configuration

- [ ] Anthropic API key is in env.swift
- [ ] API key is valid and has credits
- [ ] Internet connection available for testing

## ✅ Before First Build

1. **Clean Build Folder**
   ```
   Product → Clean Build Folder (⇧⌘K)
   ```

2. **Verify All Files Are Added**
   ```
   - Select each new .swift file in navigator
   - Check "Target Membership" in File Inspector
   - Ensure "Dobby" target is checked
   ```

3. **Check for Compile Errors**
   ```
   Product → Build (⌘B)
   Fix any errors shown
   ```

## ✅ First Run Checklist

### Simulator Testing (Limited)
- [ ] App launches successfully
- [ ] Can navigate to Scan tab
- [ ] "Paste Receipt Text" button works
- [ ] Can paste text and process
- [ ] AI categorization works (needs internet)
- [ ] Can review and save transactions
- [ ] Transactions appear in View tab

### Device Testing (Full Features)
- [ ] App launches successfully
- [ ] All simulator tests pass
- [ ] Camera permission requested
- [ ] Camera scanning works
- [ ] Photo library permission requested
- [ ] Photo import works
- [ ] OCR extracts text correctly

## 🐛 Common Build Errors & Fixes

### Error: "Cannot find 'AppConfiguration' in scope"
**Fix**: Ensure env.swift is added to target

### Error: "Cannot find 'AnthropicService' in scope"
**Fix**: Ensure AnthropicService.swift is added to target

### Error: "Missing type 'ReceiptImportResult'"
**Fix**: Ensure ReceiptImportService.swift is added to target

### Error: Missing Info.plist keys
**Fix**: Add camera and photo library usage descriptions

### Error: "'init(image:sourceType:)' is unavailable"
**Fix**: This is normal for SwiftUI previews, test on device/simulator

### Error: Network request failed
**Fix**: Check internet connection and API key

## 🚀 Ready to Build?

If all items are checked above:

1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Build**: Product → Build (⌘B)
3. **Run**: Product → Run (⌘R)
4. **Test**: Use sample receipt from TEST_RECEIPTS.md

## 📝 Testing Steps

### Quick Test (5 minutes)
1. Launch app
2. Go to Scan tab
3. Tap "Paste Receipt Text"
4. Copy receipt from TEST_RECEIPTS.md
5. Tap Process
6. Wait for AI (3-5 seconds)
7. Review items
8. Tap Save
9. Go to View tab
10. Verify data appears

### Full Test (15 minutes)
- [ ] Test camera scanning (device only)
- [ ] Test photo library import
- [ ] Test text paste
- [ ] Test with ALDI receipt
- [ ] Test with COLRUYT receipt
- [ ] Test with unknown store
- [ ] Test editing items in review
- [ ] Test deleting items
- [ ] Test canceling import
- [ ] Verify data in View tab
- [ ] Test filtering and sorting

## ✅ Post-Build Verification

After successful build and run:

- [ ] No crashes on launch
- [ ] All tabs are accessible
- [ ] Scan tab UI displays correctly
- [ ] Buttons respond to taps
- [ ] Text input works
- [ ] API calls complete successfully
- [ ] Review screen displays correctly
- [ ] Data saves and persists
- [ ] View tab shows updated data

## 🎉 Success Criteria

Your app is working correctly if:

1. ✅ You can paste a test receipt
2. ✅ AI categorizes the items (takes 3-5 seconds)
3. ✅ Review screen shows all items with categories
4. ✅ You can save the transactions
5. ✅ Transactions appear in the View tab
6. ✅ Store breakdowns update correctly

## 📞 Need Help?

If something doesn't work:

1. **Check Xcode Console** for error messages
2. **Review SETUP_GUIDE.md** for detailed instructions
3. **Use TEST_RECEIPTS.md** for known-good test data
4. **Verify API key** in env.swift
5. **Check internet connection** for AI features
6. **Try simpler test** (e.g., just text paste first)

## 🎓 Next Steps After Successful Build

1. [ ] Test with real receipts
2. [ ] Try camera scanning (on device)
3. [ ] Experiment with different stores
4. [ ] Customize categories if needed
5. [ ] Add more features!

---

**Good luck! You're almost ready to scan receipts! 🛒✨**

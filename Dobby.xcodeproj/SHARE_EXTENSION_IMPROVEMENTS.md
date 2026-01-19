# Share Extension Auto-Detect Store - Improvements

## Overview

The Share Extension has been completely redesigned to provide a **clean iOS experience** with proper **auto-detection of stores** from receipt images and text.

## What Was Fixed

### ❌ Before (Problems)

1. **No store detection** - The extension didn't detect which store the receipt was from
2. **No review screen** - Users couldn't verify or edit the data before saving
3. **Poor user experience** - Just a loading spinner, then auto-closes
4. **No error recovery** - If something went wrong, no way to fix it
5. **Missing data** - Store name wasn't included in saved receipts

### ✅ After (Solutions)

1. **✨ Automatic Store Detection**
   - Uses Vision framework to extract text from receipt images
   - Matches text against known store keywords (ALDI, COLRUYT, DELHAIZE, CARREFOUR, LIDL)
   - Shows detection status with visual feedback

2. **📱 Clean Review Screen**
   - Preview of the receipt image
   - Store picker with auto-detected store highlighted
   - Date picker with auto-extracted date
   - Receipt text preview
   - Clear "Add Receipt" button

3. **🎯 Proper State Management**
   - Processing state with progress indicator
   - Review state with editable fields
   - Success state with confirmation
   - Error state with retry option

4. **🔄 Better Error Handling**
   - Clear error messages
   - Retry functionality
   - Cancel anytime option

5. **💾 Complete Data Storage**
   - Store name included in shared data
   - Date information preserved
   - Image data saved
   - Extracted text saved

## New Features

### Auto-Detection System

The extension now automatically:

1. **Extracts text from images** using Vision OCR
2. **Detects the store** by matching keywords:
   - ALDI: "aldi", "aldi nord", "aldi süd"
   - COLRUYT: "colruyt", "okay", "bio-planet"
   - DELHAIZE: "delhaize", "ad delhaize", "proxy delhaize"
   - CARREFOUR: "carrefour", "carrefour express", "carrefour market"
   - LIDL: "lidl"
3. **Extracts the date** from receipt text using NSDataDetector
4. **Shows status** with visual indicators:
   - ✅ Green checkmark = Store detected
   - ⚠️ Orange warning = Store not detected (user should select)

### Review Interface

New professional review screen with:

- **Receipt Preview** - Shows the shared image
- **Store Selection** 
  - Tap to open store picker
  - Auto-selected if detected
  - All supported stores listed
- **Date Picker** 
  - Defaults to detected/current date
  - Easy to adjust if needed
- **Receipt Text** 
  - Scrollable text preview
  - Shows what was extracted
- **Visual Feedback**
  - Color-coded status indicators
  - Icons for each field
  - Clean, native iOS design

### State Flow

```
Share from another app
        ↓
   Processing
   (Extract & Detect)
        ↓
   Review Screen
   (Verify & Edit)
        ↓
   Saving
        ↓
   Success!
```

## Technical Implementation

### New Components

1. **ShareExtensionViewModel**
   - `@Published` state management
   - Async/await for all operations
   - Proper error handling

2. **ProcessingView**
   - Shows during extraction
   - Progress indicator
   - Status messages

3. **ReviewReceiptView**
   - Main review interface
   - Store picker sheet
   - Date picker
   - Receipt preview

4. **StorePickerView**
   - Native iOS list
   - All stores displayed
   - Selection indicator

5. **SuccessView**
   - Quick confirmation
   - Auto-dismisses

6. **ErrorView**
   - Clear error message
   - Retry button
   - Cancel option

### Data Structure Updates

**Before:**
```swift
struct ReceiptShareData: Codable {
    let imageData: Data?
    let text: String?
    let date: Date
}
```

**After:**
```swift
struct ReceiptShareData: Codable {
    let imageData: Data?
    let text: String?
    let storeName: String  // ← NEW!
    let date: Date
}

struct ReceiptData {
    let imageData: Data?
    let extractedText: String?
    var detectedStore: SupportedStore  // ← Detection info
    var date: Date
}
```

### Store Detection Logic

```swift
private func detectStore(from text: String) -> SupportedStore {
    let lowercasedText = text.lowercased()
    
    for store in SupportedStore.allCases where store != .unknown {
        for keyword in store.keywords {
            if lowercasedText.contains(keyword.lowercased()) {
                return store
            }
        }
    }
    
    return .unknown
}
```

### Vision OCR Integration

```swift
private func extractTextFromImage(_ image: UIImage) async throws -> String {
    // Uses VNRecognizeTextRequest
    // .accurate recognition level
    // Language correction enabled
    // Returns all recognized text joined with newlines
}
```

## User Experience Flow

### 1. Share Receipt from Another App

User taps share button in store app (like ALDI app) → Selects "Dobby"

### 2. Processing (Automatic)

- Extension opens
- Shows "Processing receipt..." with spinner
- Extracts text from image (if image shared)
- Detects store from text
- Extracts date from text

### 3. Review Screen (User Interaction)

**If store detected:**
- ✅ Shows detected store with green checkmark
- Date pre-filled
- User can adjust if needed
- Tap "Add Receipt" to save

**If store NOT detected:**
- ⚠️ Shows "Unknown Store" with orange warning
- User taps store field
- Picker appears with all stores
- Select correct store
- Tap "Add Receipt" to save

### 4. Success

- Shows "Receipt Added!" with green checkmark
- "Open Dobby to review" message
- Auto-dismisses after 0.8 seconds

## Design Principles

### iOS Native Feel

- **SwiftUI** throughout
- **SF Symbols** for icons
- **System colors** and gradients
- **Native sheets** and pickers
- **Smooth animations**

### Clear Visual Hierarchy

- **Icons** convey meaning at a glance
- **Color coding** for status:
  - Blue = Standard/Normal
  - Green = Success/Detected
  - Orange = Warning/Action needed
  - Red = Error (reserved for actual errors)
- **Typography** follows iOS guidelines

### Progressive Disclosure

- Shows what user needs when they need it
- Details available but not overwhelming
- Clear path to completion

## Files Modified

1. **ShareExtensionView.swift** - Complete rewrite
   - New state-based UI
   - Vision OCR integration
   - Store detection logic
   - Review interface components

2. **SharedReceiptMonitor.swift** - Updated data structure
   - Added `storeName` field to `ReceiptShareData`
   - Updated `PendingReceipt` display name

## Setup Requirements

### App Groups (Required)

Both targets need the same App Group:
- Main app: `group.com.yourname.dobby`
- Share extension: `group.com.yourname.dobby`

### Frameworks (Required)

Share extension needs:
- SwiftUI
- UniformTypeIdentifiers
- Vision (for OCR)

### Info.plist Configuration

```xml
<key>NSExtensionActivationRule</key>
<dict>
    <key>NSExtensionActivationSupportsImageWithMaxCount</key>
    <integer>1</integer>
    <key>NSExtensionActivationSupportsText</key>
    <true/>
    <key>NSExtensionActivationSupportsFileWithMaxCount</key>
    <integer>1</integer>
</dict>
```

## Testing Checklist

- [ ] Share image from Photos app
- [ ] Share from ALDI app (if available)
- [ ] Share from other store apps
- [ ] Test with clear receipt image (should detect store)
- [ ] Test with unclear image (should allow manual selection)
- [ ] Test text sharing
- [ ] Verify date detection
- [ ] Verify manual date adjustment
- [ ] Verify manual store selection
- [ ] Test cancel button
- [ ] Test error recovery
- [ ] Verify data appears in main app

## Main App Integration

The main app already has `SharedReceiptMonitor` that:

1. Monitors the shared container
2. Detects new receipts
3. Shows them in the app
4. Now includes store name!

## Future Enhancements

Possible improvements:

1. **More stores** - Add additional store keywords
2. **Better OCR** - Train custom Vision model for receipts
3. **Amount extraction** - Parse total amount from text
4. **Items detection** - List items on review screen
5. **Smart defaults** - Remember user's frequent stores
6. **Location detection** - Auto-detect store by location
7. **Haptic feedback** - Add tactile feedback on actions

## Summary

The share extension now provides a **professional, native iOS experience** with:

✅ Automatic store detection using Vision OCR  
✅ Clean review interface for verification  
✅ Easy store selection if not detected  
✅ Date detection and editing  
✅ Receipt preview  
✅ Proper error handling  
✅ Smooth animations and transitions  
✅ Complete data preservation  

It follows iOS design guidelines and feels like a built-in system feature!

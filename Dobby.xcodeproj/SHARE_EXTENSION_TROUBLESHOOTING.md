# Share Extension Auto-Detection Troubleshooting

## Issue: Store Not Auto-Detecting

If you're seeing an empty box or "Unknown Store" when sharing receipts, here's how to diagnose and fix it.

## Quick Diagnosis Checklist

When you share a receipt, check the Xcode console for debug output:

### Expected Console Output (Working)
```
📸 Image loaded: 245678 bytes
🔍 Starting OCR...
📝 Extracted text (432 chars):
ALDI BELGIQUE
Rue de Example 123
1000 Brussels
...
🏪 Detected store: ALDI
📅 Detected date: 2026-01-19
🔍 ReviewReceiptView initialized with:
   Store: ALDI
   Date: 2026-01-19
   Has image: true
   Text length: 432
```

### Problem Output (Not Working)
```
📸 Image loaded: 245678 bytes
🔍 Starting OCR...
📝 Extracted text (0 chars):
[no text]
🏪 Detected store: Unknown Store
📅 Detected date: 2026-01-19
```

## Common Issues & Solutions

### 1. OCR Returns No Text

**Symptoms:**
- Console shows "Extracted text (0 chars)"
- Store always "Unknown Store"
- Receipt text section empty

**Possible Causes:**

#### A. Missing Vision Framework
**Check:** In your Share Extension target → Build Phases → Link Binary With Libraries
**Fix:** Add `Vision.framework`

#### B. Image Format Issue
**Check:** Console output for image size
**Fix:** The code should handle this, but verify the image loads correctly

#### C. Permissions Issue
**Check:** Info.plist for Vision permissions
**Fix:** Vision OCR doesn't require permissions, but double-check no restrictions

#### D. Simulator Limitations
**Check:** Are you testing on Simulator?
**Fix:** Test on a real device - Vision works better on hardware

### 2. OCR Works But Store Not Detected

**Symptoms:**
- Console shows extracted text
- But "Detected store: Unknown Store"

**Diagnosis Steps:**

1. **Check the extracted text** in console
2. **Look for store name** - Is it there?
3. **Check spelling** - Exact match?
4. **Check keywords** - Does it match our list?

**Example Problem:**
```
Extracted text:
"ALDI SÜD BELGIUM"
```
**Issue:** Contains "SÜD" instead of "süd" (lowercase in our keywords)

**Fix:** The code already uses `.lowercased()` so this should work. If not, add more keywords.

### 3. Store Name Present But Not Matching

**Problem:** Receipt says "ALDI" but still not detected

**Debug:** Add this temporary code to see what's being compared:

```swift
private func detectStore(from text: String) -> SupportedStore {
    let lowercasedText = text.lowercased()
    print("🔍 Searching in text: \(lowercasedText.prefix(200))")
    
    for store in SupportedStore.allCases where store != .unknown {
        print("   Checking \(store.rawValue)...")
        for keyword in store.keywords {
            print("      Looking for: '\(keyword)'")
            if lowercasedText.contains(keyword.lowercased()) {
                print("      ✅ FOUND!")
                return store
            }
        }
    }
    
    print("   ❌ No store detected")
    return .unknown
}
```

### 4. Receipt Image Too Blurry

**Symptoms:**
- OCR extracts some text but misses store name
- Text is garbled or incomplete

**Solutions:**
- Test with a clearer receipt image
- Use a higher quality scan
- Try with a sample receipt known to work

## Testing Strategy

### Step 1: Test with Known Good Receipt

Create a test image with clear text:

1. Open Notes app
2. Type in large text:
   ```
   ALDI BELGIUM
   Receipt #12345
   Date: 19/01/2026
   Item 1: 5.00 EUR
   Total: 5.00 EUR
   ```
3. Take screenshot
4. Share screenshot to Dobby extension
5. Check if it detects ALDI

### Step 2: Test OCR Directly

If Step 1 fails, OCR isn't working. If it succeeds, the issue is with real receipts.

### Step 3: Test Each Store

Test receipts from each supported store:
- ALDI
- COLRUYT
- DELHAIZE  
- CARREFOUR
- LIDL

## Code Verification

### Check 1: Vision Import

In `ShareExtensionView.swift`, verify line 3:
```swift
import Vision
```

### Check 2: Store Keywords

Check the `SupportedStore` enum has correct keywords:

```swift
var keywords: [String] {
    switch self {
    case .aldi:
        return ["aldi", "aldi nord", "aldi süd"]
    case .colruyt:
        return ["colruyt", "okay", "bio-planet"]
    case .delhaize:
        return ["delhaize", "ad delhaize", "proxy delhaize"]
    case .carrefour:
        return ["carrefour", "carrefour express", "carrefour market"]
    case .lidl:
        return ["lidl"]
    case .unknown:
        return []
    }
}
```

### Check 3: Detection Logic

Verify the detection function is called:

```swift
// In processSharedItems:
let detectedStore = detectStore(from: extractedText ?? "")
print("🏪 Detected store: \(detectedStore.rawValue)")
```

### Check 4: UI Shows Detection Status

In `ReviewReceiptView`, verify this code:

```swift
HStack(spacing: 8) {
    Image(systemName: receiptData.detectedStore == .unknown ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
        .font(.caption)
        .foregroundStyle(receiptData.detectedStore == .unknown ? .orange : .green)
    
    Text(receiptData.detectedStore == .unknown ? "Store not detected - please select" : "Auto-detected: \(receiptData.detectedStore.displayName)")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

## Alternative: Manual Selection Flow

If auto-detection isn't critical right now, you can modify the UI to default to manual selection:

### Option 1: Auto-Open Picker If Unknown

```swift
.onAppear {
    if receiptData.detectedStore == .unknown {
        // Auto-show picker if not detected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingStorePicker = true
        }
    }
}
```

### Option 2: Prominent "Select Store" Button

Make the store selection more prominent if unknown:

```swift
if selectedStore == .unknown {
    // Show big "Select Store" button
    Button {
        showingStorePicker = true
    } label: {
        HStack {
            Image(systemName: "storefront.fill")
            Text("Tap to Select Store")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.orange.opacity(0.2))
        .foregroundColor(.orange)
        .cornerRadius(12)
    }
}
```

## Performance Checklist

### Device vs Simulator
- ✅ Test on real device
- ⚠️  Simulator may have issues with Vision

### Image Quality
- ✅ Clear, high-contrast receipt
- ⚠️  Blurry or low-light photos may fail

### Language Settings
- ✅ Vision supports multiple languages
- ⚠️  Check device language settings

## Quick Fixes

### Fix 1: Increase OCR Time

If OCR is timing out, there's no timeout in the current code, but you can verify the request completes:

```swift
request.recognitionLevel = .accurate  // Try .fast instead
request.usesLanguageCorrection = true
```

### Fix 2: Add More Keywords

If specific stores aren't detected, add more variations:

```swift
case .aldi:
    return [
        "aldi", 
        "aldi nord", 
        "aldi süd",
        "aldi belgium",  // ADD THIS
        "aldi belgique"  // ADD THIS
    ]
```

### Fix 3: Case-Insensitive Detection

Already implemented, but verify:

```swift
if lowercasedText.contains(keyword.lowercased()) {
    return store
}
```

## Expected Behavior Summary

### Working Correctly

1. **Share receipt** → Extension opens
2. **Shows "Processing receipt..."** with spinner (1-3 seconds)
3. **Review screen appears** with:
   - Receipt image at top
   - Store field showing detected store with ✅ icon
   - Or "Unknown Store" with ⚠️  icon
4. **User can tap store** to change if needed
5. **Tap "Add Receipt"** to save

### Not Working

1. Share receipt → Extension opens
2. Processing (quick or long)
3. Review screen shows empty/broken UI
4. OR: Store always shows "Unknown Store" even for clear receipts

## Getting Help

If still not working, provide:

1. **Console output** when sharing a receipt
2. **Screenshot** of the review screen
3. **Sample receipt** image (if possible)
4. **Device info** (real device or simulator?)
5. **iOS version**

## Last Resort: Disable Auto-Detection

If you just want manual selection for now:

```swift
func processSharedItems(_ items: [Any]) async {
    // ... existing code ...
    
    // TEMPORARILY: Always set to unknown
    let detectedStore = SupportedStore.unknown  // Force manual selection
    let detectedDate = Date()  // Use current date
    
    // Rest of code...
}
```

This will make the extension work but require manual store selection every time.

## Success Criteria

You'll know it's working when:

1. ✅ Console shows extracted text from receipt
2. ✅ Console shows detected store (when store name present)
3. ✅ Review screen shows ✅ green checkmark with store name
4. ✅ Or ⚠️  orange warning if not detected (expected for unknown stores)
5. ✅ Manual selection always works as backup

## Next Steps

Once basic detection works:

1. **Tune keywords** for your region's stores
2. **Add more stores** to the enum
3. **Improve OCR** with preprocessing
4. **Add analytics** to track detection rate
5. **Train custom model** for better accuracy

The current implementation should work for clear receipts with standard store names!

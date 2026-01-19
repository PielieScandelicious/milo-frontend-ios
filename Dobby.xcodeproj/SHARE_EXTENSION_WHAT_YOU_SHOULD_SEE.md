# Share Extension: What You Should See

## Complete Flow with Screenshots Description

### Step 1: Share a Receipt

**From Photos app or any app:**
- Tap the share button
- Scroll to find "Dobby" in the share sheet
- Tap on Dobby

---

### Step 2: Processing Screen (1-3 seconds)

**You should see:**
```
┌─────────────────────────────────┐
│     Add to Dobby            │
├─────────────────────────────────┤
│                                 │
│                                 │
│         ⚙️  [Spinner]           │
│                                 │
│     Reading receipt text...     │
│                                 │
│                                 │
└─────────────────────────────────┘
```

**In Xcode Console you should see:**
```
📸 Image loaded: 245678 bytes
🔍 Starting OCR...
```

---

### Step 3A: Review Screen - Store DETECTED ✅

**You should see:**

```
┌─────────────────────────────────┐
│     Add to Dobby        [Cancel]│
├─────────────────────────────────┤
│  ┌─────────────────────────┐    │
│  │   [Receipt Image]       │    │
│  │                         │    │
│  └─────────────────────────┘    │
│                                 │
│  ╔═══════════════════════════╗  │
│  ║ Store                     ║  │
│  ║ 🏪  ALDI              >  ║  │
│  ║                           ║  │
│  ║ ✅ Auto-detected: ALDI    ║  │
│  ║ ─────────────────────────  ║  │
│  ║ Date                      ║  │
│  ║ 📅  Jan 19, 2026          ║  │
│  ╚═══════════════════════════╝  │
│                                 │
│  Receipt Text                   │
│  ┌─────────────────────────┐    │
│  │ ALDI BELGIUM            │    │
│  │ Receipt #12345          │    │
│  │ Date: 19/01/2026        │    │
│  │ ...                     │    │
│  └─────────────────────────┘    │
│                                 │
│  ┌─────────────────────────┐    │
│  │  ✓  Add Receipt         │    │
│  └─────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

**Key indicators that detection worked:**
1. ✅ Green checkmark icon
2. Store name shown (e.g., "ALDI")
3. Blue store icon (not orange)
4. Text says "Auto-detected: ALDI"
5. Receipt text section shows the extracted text

**In Console:**
```
📝 Extracted text (432 chars):
ALDI BELGIUM
Receipt #12345
...
🏪 Detected store: ALDI
✅ Receipt saved successfully!
```

---

### Step 3B: Review Screen - Store NOT DETECTED ⚠️

**You should see:**

```
┌─────────────────────────────────┐
│     Add to Dobby        [Cancel]│
├─────────────────────────────────┤
│  ┌─────────────────────────┐    │
│  │   [Receipt Image]       │    │
│  │                         │    │
│  └─────────────────────────┘    │
│                                 │
│  ╔═══════════════════════════╗  │
│  ║ Store                     ║  │
│  ║ 🏪  Unknown Store     >  ║  │
│  ║                           ║  │
│  ║ ⚠️  Store not detected    ║  │
│  ║     please select         ║  │
│  ║ ─────────────────────────  ║  │
│  ║ Date                      ║  │
│  ║ 📅  Jan 19, 2026          ║  │
│  ╚═══════════════════════════╝  │
│                                 │
│  Receipt Text                   │
│  ┌─────────────────────────┐    │
│  │ LOCAL SHOP              │    │
│  │ Receipt #999            │    │
│  │ ...                     │    │
│  └─────────────────────────┘    │
│                                 │
│  ┌─────────────────────────┐    │
│  │  ✓  Add Receipt         │    │
│  └─────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

**Key indicators:**
1. ⚠️  Orange warning icon
2. "Unknown Store" shown
3. Orange store icon
4. Text says "Store not detected - please select"
5. User MUST tap store field to select

**In Console:**
```
📝 Extracted text (125 chars):
LOCAL SHOP
Receipt #999
...
🏪 Detected store: Unknown Store
```

---

### Step 4: Manual Store Selection (if needed)

**When you tap the store field:**

```
┌─────────────────────────────────┐
│     Select Store           [Done]│
├─────────────────────────────────┤
│                                 │
│  🏪  ALDI                     │
│  ───────────────────────────     │
│  🏪  CARREFOUR                │
│  ───────────────────────────     │
│  🏪  COLRUYT                  │
│  ───────────────────────────     │
│  🏪  DELHAIZE                 │
│  ───────────────────────────     │
│  🏪  LIDL                     │
│  ───────────────────────────     │
│  ⚠️   Unknown Store    ✓      │
│                                 │
└─────────────────────────────────┘
```

**What to do:**
1. Scroll through list
2. Tap the correct store
3. Sheet dismisses
4. You're back to review screen
5. Selected store now shows with ✓

---

### Step 5: Save

**After tapping "Add Receipt":**

```
┌─────────────────────────────────┐
│     Add to Dobby            │
├─────────────────────────────────┤
│                                 │
│                                 │
│         ⚙️  [Spinner]           │
│                                 │
│       Saving receipt...         │
│                                 │
│                                 │
└─────────────────────────────────┘
```

**Brief moment (< 1 second)**

---

### Step 6: Success

**You should see:**

```
┌─────────────────────────────────┐
│     Add to Dobby            │
├─────────────────────────────────┤
│                                 │
│                                 │
│      ✅                         │
│   [Big green checkmark]         │
│                                 │
│   Receipt Added!                │
│                                 │
│   Open Dobby to review          │
│                                 │
└─────────────────────────────────┘
```

**Automatically closes after 0.8 seconds**

---

## What Each Element Means

### Icons

| Icon | Meaning |
|------|---------|
| ✅ | Store was automatically detected |
| ⚠️  | Store was NOT detected, manual selection needed |
| 🏪 (blue) | Store is selected/detected |
| 🏪 (orange) | No store selected yet |
| 📅 | Date field |
| ✓ | Checkmark (action button or selected item) |
| > | Chevron (tap to see more options) |

### Colors

| Color | Meaning |
|-------|---------|
| **Blue** | Normal/selected state, primary actions |
| **Green** | Success, detected correctly |
| **Orange** | Warning, attention needed |
| **Gray** | Secondary information, disabled |

### Text Indicators

| Text | What It Means |
|------|---------------|
| "Auto-detected: ALDI" | System found "ALDI" in receipt text |
| "Store not detected - please select" | System couldn't find a known store name |
| "Reading receipt text..." | OCR in progress |
| "Detecting store..." | Matching text against store keywords |
| "Saving receipt..." | Writing to shared container |
| "Receipt Added!" | Successfully saved |

---

## Troubleshooting: What You're NOT Seeing

### Problem 1: Blank Store Field

**You see:**
```
Store: [empty or just "   "]
```

**This means:**
- UI bug
- Check console for errors
- DetectedStore might be nil (shouldn't happen)

**Expected instead:**
```
Store: Unknown Store   (if not detected)
OR
Store: ALDI            (if detected)
```

### Problem 2: No Green Checkmark Ever

**You see:**
- Always orange warning
- Even for clear ALDI receipts

**This means:**
- OCR not extracting text, OR
- Detection logic not running, OR
- Keywords don't match

**Check console** for:
```
📝 Extracted text (0 chars):    ← OCR FAILED
[no text]

OR

📝 Extracted text (432 chars):  ← OCR WORKED
...
🏪 Detected store: Unknown Store ← DETECTION FAILED
```

### Problem 3: No Receipt Text Section

**Receipt Text section is missing or empty**

**This means:**
- `receiptData.extractedText` is nil or empty
- OCR didn't work
- Check console for OCR output

### Problem 4: Extension Crashes

**Extension closes immediately or shows error**

**Check:**
- App Groups configured correctly
- Vision framework linked
- No nil unwrapping crashes

---

## Expected Console Output (Normal Flow)

### Successful Detection

```
📸 Image loaded: 234567 bytes
🔍 Starting OCR...
📝 Extracted text (387 chars):
ALDI BELGIUM
Rue Example 123
1000 Bruxelles
Tel: +32 2 xxx xxxx
TVA: BE 0123.456.789

Date: 19/01/2026  14:35
Receipt: 1234-5678-9012

Bananas                   2.50
Milk 1L                   1.20
Bread                     2.00
---------------------------------
TOTAL EUR                 5.70

Thank you!
Visit us again

🏪 Detected store: ALDI
📅 Detected date: 2026-01-19 14:35:00 +0000
🔍 ReviewReceiptView initialized with:
   Store: ALDI
   Date: 2026-01-19 14:35:00 +0000
   Has image: true
   Text length: 387
[User taps Add Receipt]
✅ Receipt saved successfully!
```

### No Detection (But Working)

```
📸 Image loaded: 123456 bytes
🔍 Starting OCR...
📝 Extracted text (156 chars):
LOCAL GROCERY
123 Main Street
City, Country

Date: 19/01/2026
Item 1    5.00
Item 2    3.00
Total     8.00

🏪 Detected store: Unknown Store
📅 Detected date: 2026-01-19 00:00:00 +0000
🔍 ReviewReceiptView initialized with:
   Store: Unknown Store
   Date: 2026-01-19 00:00:00 +0000
   Has image: true
   Text length: 156
[User manually selects ALDI from picker]
[User taps Add Receipt]
✅ Receipt saved successfully!
```

### OCR Failed

```
📸 Image loaded: 234567 bytes
🔍 Starting OCR...
📝 Extracted text (0 chars):
[no text]
🏪 Detected store: Unknown Store
📅 Detected date: 2026-01-19 12:00:00 +0000
🔍 ReviewReceiptView initialized with:
   Store: Unknown Store
   Date: 2026-01-19 12:00:00 +0000
   Has image: true
   Text length: 0
⚠️  No text extracted - manual selection required
```

---

## Quick Reference: Is It Working?

### ✅ Working Correctly

- [ ] Extension opens when sharing image
- [ ] Shows "Processing..." screen
- [ ] Console shows "Image loaded"
- [ ] Console shows "Starting OCR"
- [ ] Console shows extracted text (if receipt is clear)
- [ ] Review screen appears
- [ ] Can see receipt image preview
- [ ] Store field shows something (even if "Unknown Store")
- [ ] Can tap store field to open picker
- [ ] All stores listed in picker
- [ ] Can select a store
- [ ] Selected store appears in review
- [ ] Can tap "Add Receipt"
- [ ] Shows "Saving..." then "Success!"
- [ ] Extension closes
- [ ] Receipt appears in main Dobby app

### ❌ Not Working

Common signs of problems:

- [ ] Extension doesn't appear in share sheet
- [ ] Extension opens but crashes immediately
- [ ] Stuck on "Processing..." forever
- [ ] Shows error message
- [ ] Review screen is blank/broken
- [ ] Store field is empty (not even "Unknown Store")
- [ ] Can't tap store field
- [ ] Picker doesn't open
- [ ] No stores in picker
- [ ] Tapping "Add Receipt" does nothing
- [ ] Never shows success screen
- [ ] Receipt doesn't appear in main app

### 🟡 Partially Working (Expected)

These are NORMAL if receipt isn't from a supported store:

- [ ] Shows "Unknown Store" - **THIS IS OK!**
- [ ] Orange warning icon - **THIS IS OK!**
- [ ] "Store not detected" message - **THIS IS OK!**
- [ ] User has to manually select - **THIS IS OK!**

The system is working correctly. Not every receipt will auto-detect.

---

## Test Cases

### Test 1: Known Store (ALDI)

1. Find an ALDI receipt image (or create test image with "ALDI" text)
2. Share to Dobby
3. **Expected:** ✅ Green checkmark, "Auto-detected: ALDI"

### Test 2: Unknown Store

1. Share any image without store names
2. **Expected:** ⚠️  Orange warning, "Unknown Store", manual selection works

### Test 3: Text Share

1. Copy text: "ALDI BELGIUM Receipt Total: 5.00 EUR"
2. Share text to Dobby
3. **Expected:** ✅ Detects ALDI (or should)

### Test 4: Each Store

Test with receipts from:
- [ ] ALDI → Should detect ✅
- [ ] COLRUYT → Should detect ✅
- [ ] DELHAIZE → Should detect ✅
- [ ] CARREFOUR → Should detect ✅
- [ ] LIDL → Should detect ✅
- [ ] Unknown store → Should show warning ⚠️

---

## Summary: The Two Main Scenarios

### Scenario A: Detection Works! 🎉

```
Share → Process (OCR) → ✅ ALDI Detected → Review → Save → Success!
         1-3 sec         Green checkmark   Verify   Quick   Close
```

**User sees:** Professional experience, feels automatic

### Scenario B: Manual Selection (Also Fine!) ✋

```
Share → Process (OCR) → ⚠️  Unknown → User Picks → Save → Success!
         1-3 sec         Orange warn   From list   Quick   Close
```

**User sees:** Clear guidance, easy selection

Both scenarios are valid and should work smoothly!

---

## What To Do If Nothing Works

1. **Check Xcode console** - Look for errors
2. **Check App Groups** - Same identifier in both targets?
3. **Check Vision framework** - Linked in Share Extension target?
4. **Test on real device** - Simulator may have issues
5. **Read SHARE_EXTENSION_TROUBLESHOOTING.md** - Detailed debugging steps
6. **Add more print statements** - See exactly where it fails

The code is solid. Most issues are configuration-related!

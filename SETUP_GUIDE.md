# Dobby Receipt Import - Setup Guide

## Overview
This guide will help you set up the Dobby app to receive receipts shared from other apps like the Aldi app or any store app.

## Files Created

### 1. Core Services
- **env.swift** - Stores the Anthropic API key configuration
- **AnthropicService.swift** - Handles AI categorization using Claude
- **ReceiptImportService.swift** - Processes receipts, detects stores, and extracts text from images
- **ReceiptScanView.swift** - Main UI for scanning/importing receipts
- **ReceiptReviewView.swift** - UI for reviewing and editing imported transactions

### 2. Updated Files
- **TransactionModel.swift** - Added methods to add/delete transactions
- **StoreBreakdownModel.swift** - Updated to work with live transaction data
- **ContentView.swift** - Integrated TransactionManager as environment object
- **OverviewView.swift** - Connected to TransactionManager for real-time updates

## Features Implemented

### ✅ Receipt Import Methods
1. **Camera Capture** - Take a photo of a physical receipt
2. **Photo Library** - Choose an existing receipt photo
3. **Text Input** - Paste receipt text directly

### ✅ Store Detection
Automatically detects these stores:
- ALDI
- COLRUYT
- DELHAIZE
- CARREFOUR
- LIDL
- Falls back to "Unknown Store" if not detected

### ✅ AI Categorization
Uses Anthropic's Claude to categorize items into:
- Meat & Fish
- Alcohol
- Drinks (Soft/Soda)
- Drinks (Water)
- Household
- Snacks & Sweets
- Fresh Produce
- Dairy & Eggs
- Ready Meals
- Bakery
- Pantry
- Personal Care
- Others (fallback)

### ✅ Transaction Review
- View all imported items before saving
- Edit store name and date
- Delete individual items
- See total amount and category breakdown
- Swipe to delete items
- Save to transaction history

## Required Xcode Configuration

### 1. Add Required Capabilities

#### In Xcode:
1. Select your project in the Project Navigator
2. Select your target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add **"Camera Usage"**

### 2. Update Info.plist

Add these keys to your Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>Dobby needs access to your camera to scan receipts</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Dobby needs access to your photo library to import receipt images</string>
```

### 3. Configure App Transport Security (for Anthropic API)

The Anthropic API uses HTTPS, so no additional ATS configuration is needed. However, ensure you have internet connectivity.

## How to Use the App

### Scanning a Receipt

1. **Launch the app** and go to the "Scan" tab
2. **Choose an import method**:
   - Tap "Take Photo" to use camera
   - Tap "Choose from Library" to select existing photo
   - Tap "Paste Receipt Text" to manually paste text

3. **Wait for processing**:
   - The app extracts text using Vision framework
   - Detects the store automatically
   - Sends items to Anthropic Claude for categorization
   - Shows progress indicator during processing

4. **Review imported items**:
   - Check the detected store name
   - Verify the date
   - Review each item and its category
   - Edit or delete items as needed
   - See total amount and category breakdown

5. **Save transactions**:
   - Tap "Save" to add to your transaction history
   - Items will appear in the "View" tab
   - Data is integrated with existing visualizations

### Viewing Your Data

1. Go to the **"View" tab** to see your store breakdowns
2. Filter by store or period
3. Sort by highest/lowest spend or store name
4. Tap on a store to see detailed category breakdown

## Testing the Feature

### Test with Sample Receipt Text

Here's sample receipt text you can use to test:

```
ALDI
Store #123
123 Main Street

Date: 18/01/2026

Bananas                 2.50
Milk 1L                 1.20
Chicken Breast          8.50
White Bread             1.50
Eggs Dozen              3.50
Yogurt 4-pack          2.80

Total:                 20.00

Thank you for shopping at ALDI!
```

### Expected Result:
- Store: ALDI (auto-detected)
- Date: 18/01/2026
- 6 items categorized:
  - Bananas → Fresh Produce
  - Milk 1L → Dairy & Eggs
  - Chicken Breast → Meat & Fish
  - White Bread → Bakery
  - Eggs Dozen → Dairy & Eggs
  - Yogurt 4-pack → Dairy & Eggs

## Troubleshooting

### "Invalid API response" Error
- Check internet connection
- Verify Anthropic API key in env.swift is correct
- Ensure API key has valid credits

### "Failed to extract text" Error
- Make sure receipt image is clear and well-lit
- Try rotating the image
- Use the text paste option instead

### Store not detected
- The system uses keywords like "aldi", "colruyt", etc.
- If not detected, you can still manually identify it in the review screen
- Or the store name will be extracted from the receipt

### Camera/Photo Library not working
- Check Info.plist has the required usage descriptions
- Verify app has permission in Settings → Privacy → Camera/Photos

## Future Enhancements (Not Yet Implemented)

### Share Extension
To receive receipts from other apps, you'll need to:

1. Add a Share Extension target to your project
2. Configure it to accept images and text
3. Use a shared App Group to pass data to main app

### Steps for Share Extension (Advanced):
```
1. File → New → Target → Share Extension
2. Name it "Dobby Share Extension"
3. Set up App Groups in Capabilities
4. Share the TransactionManager via App Groups
5. Create a simplified UI for the extension
```

This would allow sharing directly from the Aldi app or any app!

## API Costs

**Anthropic Claude API Costs:**
- Model: claude-3-5-sonnet-20241022
- Input: ~$3 per million tokens
- Output: ~$15 per million tokens
- Typical receipt: ~500 input tokens, ~200 output tokens
- **Cost per receipt: ~$0.004** (less than half a cent)

Your API key should work for thousands of receipts!

## Data Privacy

- All processing happens on-device except AI categorization
- Receipt text is sent to Anthropic for categorization
- No receipt data is stored by Anthropic (per their policy)
- Transaction data is stored locally on your device
- No cloud sync (you can add this later with CloudKit)

## Next Steps

1. ✅ Build and run the app
2. ✅ Test with the sample receipt text above
3. ✅ Try taking a photo of a real receipt
4. ✅ Verify transactions appear in the View tab
5. 🚀 Add your own customizations!

## Code Architecture

```
Dobby/
├── env.swift                    # API configuration
├── DobbyApp.swift              # App entry point
├── ContentView.swift           # Main tab view
│
├── Models/
│   ├── TransactionModel.swift      # Transaction data model
│   └── StoreBreakdownModel.swift   # Store breakdown model
│
├── Services/
│   ├── AnthropicService.swift      # AI categorization
│   └── ReceiptImportService.swift  # Receipt processing
│
├── Views/
│   ├── ReceiptScanView.swift       # Scan interface
│   ├── ReceiptReviewView.swift     # Review interface
│   └── OverviewView.swift          # Data visualization
│
└── [Other existing views...]
```

## Support

If you encounter any issues:
1. Check this guide
2. Review error messages in Xcode console
3. Verify API key and internet connection
4. Test with sample data first

Happy scanning! 🎉

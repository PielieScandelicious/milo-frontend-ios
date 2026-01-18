# Dobby - AI-Powered Receipt Tracker

An iOS app that automatically categorizes grocery receipts using AI.

## Quick Start

### 1. Configure Permissions
Add to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Dobby needs access to your camera to scan receipts</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Dobby needs access to your photo library to import receipts</string>
```

### 2. Build & Run
```bash
1. Open Dobby.xcodeproj in Xcode
2. Select your development team
3. Build and run (⌘R)
```

### 3. Test It Out
1. Go to "Scan" tab
2. Tap "Paste Receipt Text"
3. Copy this sample receipt:

```
ALDI
18/01/2026

Bananas                 2.50
Milk 1L                 1.20
Chicken Breast          8.50
White Bread             1.50
Eggs Dozen              3.50

Total: 17.20 EUR
```

4. Tap "Process"
5. Wait for AI categorization (~3-5 seconds)
6. Review items and tap "Save"
7. Go to "View" tab to see your data!

## Features

- 📷 **Camera Scanning** - Scan physical receipts
- 🖼️ **Photo Import** - Import from library
- 📝 **Text Paste** - Quick text input
- 🤖 **AI Categorization** - Anthropic Claude powered
- 🏪 **Store Detection** - Auto-detects ALDI, COLRUYT, DELHAIZE, CARREFOUR, LIDL
- 📊 **Data Visualization** - Beautiful charts and breakdowns
- ✏️ **Review & Edit** - Confirm before saving
- 🎨 **iOS Design** - Native SwiftUI interface

## How It Works

```
Receipt → Store Detection → AI Categorization → Review → Save → Visualize
```

## Categories

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
- Others

## Documentation

- 📖 **SETUP_GUIDE.md** - Complete setup instructions
- 🧪 **TEST_RECEIPTS.md** - Sample receipts for testing
- 📋 **IMPLEMENTATION_SUMMARY.md** - Full feature documentation

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Internet connection (for AI categorization)

## API Cost

~$0.004 per receipt (less than half a cent) using Anthropic Claude API

## Privacy

- Receipt images processed locally
- Only extracted text sent to Anthropic
- All data stored on device
- No cloud sync

## Created Files

```
Dobby/
├── env.swift                       # API configuration
├── AnthropicService.swift         # AI service
├── ReceiptImportService.swift     # Import logic
├── ReceiptScanView.swift          # Scan UI
├── ReceiptReviewView.swift        # Review UI
└── [Updated existing files]
```

## License

Created for personal use. Anthropic API key included is for development only.

---

**Built with ❤️ using SwiftUI, Vision, and Anthropic Claude**

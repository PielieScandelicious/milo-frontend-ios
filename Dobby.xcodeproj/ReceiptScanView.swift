# Share Extension Setup Guide

## Overview

This guide shows you how to add a **Share Extension** to your Dobby app, allowing you to share receipts directly from other apps (like the Aldi app) into Dobby.

## What is a Share Extension?

A Share Extension appears in the iOS share sheet (the pop-up you see when tapping the share button). When installed, Dobby will appear as an option when you share images or text from any app.

## Step-by-Step Setup

### 1. Create Share Extension Target

1. Open your Dobby project in Xcode
2. **File → New → Target**
3. Scroll to **"Application Extension"** section
4. Select **"Share Extension"**
5. Click **Next**
6. **Product Name**: `Dobby Share Extension`
7. **Team**: Select your development team
8. **Language**: Swift
9. **Include UI**: Yes (default)
10. Click **Finish**
11. When asked **"Activate scheme?"** → Click **Cancel** (we'll use the main app scheme)

### 2. Configure App Groups

Both your main app and share extension need to share data via an **App Group**.

#### For Main App Target:

1. Select your project in the navigator
2. Select the **Dobby** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **App Groups**
6. Click **+** under App Groups
7. Enter: `group.com.yourname.dobby` (replace `yourname` with your actual identifier)
8. Make sure the checkbox is **checked**

#### For Share Extension Target:

1. Select the **Dobby Share Extension** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and enter the **same** group: `group.com.yourname.dobby`
6. Check the checkbox

> **Important**: The App Group identifier must be **exactly the same** in both targets!

### 3. Replace Share Extension Files

Xcode creates default files for the extension. We need to replace them with our custom ones.

#### Delete These Files:

In the **Dobby Share Extension** folder in the navigator:
- ❌ Delete `ShareViewController.swift` (the default one)
- ❌ Delete `MainInterface.storyboard` (we're using SwiftUI)

#### Add New Files:

1. Drag **ShareViewController.swift** (the new one I created) into the **Dobby Share Extension** group
2. Drag **ShareExtensionView.swift** into the **Dobby Share Extension** group
3. When the dialog appears:
   - ✅ Check **"Copy items if needed"**
   - ✅ Check **"Dobby Share Extension"** target
   - ⚠️ **DO NOT** check "Dobby" target (share extension files shouldn't be in main app)
   - Click **Finish**

### 4. Update Info.plist for Share Extension

1. In the navigator, expand **Dobby Share Extension** folder
2. Find and open **Info.plist**
3. Expand **NSExtension → NSExtensionAttributes**
4. Find **NSExtensionActivationRule**
5. Replace the entire activation rule section with this:

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

This tells iOS that your extension accepts:
- Images (receipts photos)
- Text (copied receipt text)
- Files (PDF receipts)

6. Also find **NSExtensionMainStoryboard** and **delete it**
7. Add this instead:

```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
```

This tells iOS to use our custom `ShareViewController` instead of a storyboard.

### 5. Add Shared Files to Main App

The main app needs to know about shared receipts.

1. Drag **SharedReceiptMonitor.swift** into your main **Dobby** group
2. When dialog appears:
   - ✅ Check **"Dobby"** target
   - ❌ **DO NOT** check "Dobby Share Extension" target
   - Click **Finish**

### 6. Update App Group Identifier in Code

You need to update the App Group identifier in the code to match yours:

#### In ShareExtensionView.swift:

Find this line:
```swift
forSecurityApplicationGroupIdentifier: "group.com.yourname.dobby"
```

Replace `yourname` with your actual identifier.

#### In SharedReceiptMonitor.swift:

Find this line:
```swift
private let containerIdentifier = "group.com.yourname.dobby"
```

Replace with the same identifier.

### 7. Update Main App to Monitor Shared Receipts

Now we need to integrate the monitor into your main app.

#### Option A: Integrate with Existing ReceiptScanView

Let me check your existing ReceiptScanView:

<function_calls>
<invoke name="str_replace_based_edit_tool">
<parameter name="command">view
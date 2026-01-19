# Share Extension Info.plist Configuration

## Required Configuration

Your Share Extension's Info.plist needs the following configuration to accept images:

### Complete NSExtension Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Other keys... -->
    
    <!-- Share Extension Configuration -->
    <key>NSExtension</key>
    <dict>
        <!-- Extension attributes -->
        <key>NSExtensionAttributes</key>
        <dict>
            <!-- Accept only images -->
            <key>NSExtensionActivationRule</key>
            <dict>
                <!-- Maximum 1 image at a time -->
                <key>NSExtensionActivationSupportsImageWithMaxCount</key>
                <integer>1</integer>
            </dict>
        </dict>
        
        <!-- Use Swift class instead of Storyboard -->
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
        
        <!-- Extension point identifier -->
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
    </dict>
</dict>
</plist>
```

## Alternative: Using Storyboard (Not Recommended)

If you prefer to use a Storyboard (though our implementation doesn't):

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    
    <!-- Use Storyboard -->
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

## Advanced: Accept Multiple File Types

To accept both images and PDFs:

```xml
<key>NSExtensionActivationRule</key>
<dict>
    <!-- Accept up to 1 image -->
    <key>NSExtensionActivationSupportsImageWithMaxCount</key>
    <integer>1</integer>
    
    <!-- Or accept up to 1 PDF -->
    <key>NSExtensionActivationSupportsFileWithMaxCount</key>
    <integer>1</integer>
</dict>
```

## Using Predicate for Fine Control

For more complex rules, use a predicate string:

```xml
<key>NSExtensionActivationRule</key>
<string>SUBQUERY (
    extensionItems,
    $extensionItem,
    SUBQUERY (
        $extensionItem.attachments,
        $attachment,
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.image"
    ).@count == 1
).@count == 1</string>
```

This ensures exactly 1 image is shared.

## Debugging Info.plist Issues

### Extension doesn't appear in share sheet

Check:
1. ✅ NSExtensionPointIdentifier is `com.apple.share-services`
2. ✅ NSExtensionActivationRule matches what you're sharing
3. ✅ Extension target is included in your app's build

### "Could not instantiate view controller" error

Fix:
1. ✅ Use `NSExtensionPrincipalClass` (not `NSExtensionMainStoryboard`)
2. ✅ Class name format: `$(PRODUCT_MODULE_NAME).ShareViewController`
3. ✅ ShareViewController class exists and is public/internal

### Testing Your Configuration

Run this command in Terminal to see your extension's configuration:

```bash
# Get your app's bundle ID first
defaults read /Applications/YourApp.app/Contents/Info.plist CFBundleIdentifier

# Then check the extension
plutil -p /Applications/YourApp.app/PlugIns/ShareExtension.appex/Info.plist
```

## Quick Verification Checklist

- [ ] NSExtension key exists
- [ ] NSExtensionPointIdentifier = "com.apple.share-services"
- [ ] NSExtensionActivationRule configured for images
- [ ] NSExtensionPrincipalClass points to ShareViewController
- [ ] Extension target builds successfully
- [ ] App Groups configured in both targets

## Common Activation Rules

### Images Only (Current Implementation)
```xml
<key>NSExtensionActivationSupportsImageWithMaxCount</key>
<integer>1</integer>
```

### Text Content
```xml
<key>NSExtensionActivationSupportsText</key>
<true/>
```

### Web URLs
```xml
<key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
<integer>1</integer>
```

### Files
```xml
<key>NSExtensionActivationSupportsFileWithMaxCount</key>
<integer>5</integer>
```

## Example: Full Info.plist

Here's a complete minimal Info.plist for the Share Extension:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    
    <key>CFBundleDisplayName</key>
    <string>Dobby</string>
    
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    
    <key>CFBundleVersion</key>
    <string>1</string>
    
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsImageWithMaxCount</key>
                <integer>1</integer>
            </dict>
        </dict>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
    </dict>
</dict>
</plist>
```

## Additional Resources

- [App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [Share Extension Documentation](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller)
- [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)

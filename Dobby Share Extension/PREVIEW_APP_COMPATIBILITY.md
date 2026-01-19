# Preview App Compatibility Fix

## The Problem

The Share Extension worked in the Photos app but not in the Preview app. This is because different apps share content using different UTI (Uniform Type Identifier) formats.

## Why Preview is Different

### Photos App Shares As:
- `public.image` (UTType.image)
- Direct UIImage objects
- Standard image formats

### Preview App Shares As:
- `public.file-url` (UTType.fileURL) - Most common
- `public.data` (UTType.data)
- Sometimes `public.url` with file:// scheme
- Direct file paths to temporary copies

Preview often shares images as **file URLs** pointing to temporary files rather than image objects, which is why our extension wasn't catching them.

## The Solution

### 1. **Enhanced Type Detection**

Added comprehensive logging and priority-based type checking:

```swift
print("📋 Available type identifiers:")
for identifier in itemProvider.registeredTypeIdentifiers {
    print("  - \(identifier)")
}
```

This helps debug what Preview (or any app) is actually sending.

### 2. **Priority Order for Loading**

The extension now tries loading in this order:

1. **UTType.image** - Standard image type (Photos, Safari, etc.)
2. **UTType.data** - Raw data that might be an image (Preview sometimes)
3. **UTType.fileURL** - File URL to an image file (Preview most often)
4. **UTType.url** - Generic URL
5. **UTType.pdf** - PDF documents
6. **Specific formats** - "public.jpeg", "public.png", "public.heic"

### 3. **New Helper Methods**

#### loadFileURL()
Handles file URLs from Preview:

```swift
private func loadFileURL(_ itemProvider: NSItemProvider) {
    itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, ...) { item, error in
        guard let fileURL = item as? URL else { return }
        
        // Check file extension
        let pathExtension = fileURL.pathExtension.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "tif"]
        
        if imageExtensions.contains(pathExtension) {
            // Load image from file
            let data = try? Data(contentsOf: fileURL)
            let image = UIImage(data: data)
            // Save it!
        }
    }
}
```

Supported image extensions:
- jpg, jpeg
- png
- heic, heif (Apple's format)
- gif
- bmp
- tiff, tif

Also handles PDF files shared from Preview!

#### loadDataAsImage()
Handles raw data that might be an image:

```swift
private func loadDataAsImage(_ itemProvider: NSItemProvider) {
    itemProvider.loadItem(forTypeIdentifier: UTType.data.identifier, ...) { item, error in
        var imageData: Data?
        
        if let data = item as? Data {
            imageData = data
        } else if let url = item as? URL {
            // Sometimes data is provided as a URL to the data
            imageData = try? Data(contentsOf: url)
        }
        
        guard let image = UIImage(data: imageData) else { return }
        // Save it!
    }
}
```

### 4. **Improved Error Messages**

Errors now show what type was actually received:

```swift
let types = itemProvider.registeredTypeIdentifiers.joined(separator: ", ")
updateStatus(error: "Unsupported content type. Found: \(types)")
```

This helps debugging if a particular app sends an unexpected format.

## How to Test

### In Preview App:

1. Open an image in Preview (any format: PNG, JPEG, PDF, etc.)
2. Click Share button in toolbar
3. Select "Dobby" from the share sheet
4. Check Xcode Console for logs:

```
📋 Available type identifiers:
  - public.file-url
  - public.jpeg
✅ Found UTType.fileURL, loading...
📂 File URL: file:///var/folders/.../image.jpg
📂 Path extension: jpg
✅ Loaded image from file URL
✅ Receipt saved, showing success animation...
```

### In Photos App:

Should still work exactly as before:

```
📋 Available type identifiers:
  - public.image
  - public.jpeg
✅ Found UTType.image, loading...
✅ Receipt saved, showing success animation...
```

### In Safari:

Right-click image → Share → Dobby:

```
📋 Available type identifiers:
  - public.url
  - public.image
✅ Found UTType.image, loading...
```

### In Files App:

Select image file → Share → Dobby:

```
📋 Available type identifiers:
  - public.file-url
  - public.jpeg
✅ Found UTType.fileURL, loading...
```

## Supported Apps & Formats

### ✅ Now Works With:

| App | Share Format | How We Handle It |
|-----|-------------|------------------|
| Photos | public.image | loadImageFromProvider() |
| Preview | public.file-url | loadFileURL() |
| Safari | public.image / public.url | loadImageFromProvider() / loadURLFromProvider() |
| Files | public.file-url | loadFileURL() |
| Mail | varies | Multiple handlers |
| Notes | public.data | loadDataAsImage() |
| Third-party | varies | Tries all handlers |

### ✅ Supported Image Formats:

- JPEG (.jpg, .jpeg)
- PNG (.png)
- HEIC/HEIF (.heic, .heif) - Apple's modern format
- GIF (.gif)
- BMP (.bmp)
- TIFF (.tiff, .tif)
- PDF (.pdf) - Converted to image

## Debug Console Output

When sharing from Preview, you'll see:

```
📋 Available type identifiers:
  - public.file-url
  - public.jpeg
✅ Found UTType.fileURL, loading...
📂 File URL: file:///private/var/folders/xx/.../image.jpg
📂 Path extension: jpg
✅ Loaded image from file URL
✅ App Group container: /private/var/folders/.../group.com.dobby.app
✅ Receipts directory created/verified: .../receipts
📝 Saving to: .../receipt_20260119_123456_789.jpg
✅ Image compressed: 245678 bytes
✅ File written successfully
✅ File verified at: .../receipt_20260119_123456_789.jpg
✅ Receipt saved, showing success animation...
🎉 showSuccess called
🎉 Starting checkmark animation
🎉 Checkmark animation finished: true
✅ Success animation complete, waiting 2.5 seconds...
✅ Starting dismissal animation...
👋 Starting dismissal animation
👋 Dismissal animation finished: true
✅ Dismissal complete, completing request...
```

## Troubleshooting

### If Preview still doesn't work:

1. **Check Console for type identifiers** - See what Preview is actually sending
2. **Look for error messages** - "Unsupported content type. Found: ..."
3. **Check file extensions** - Is it a format we support?
4. **Try different file types** - JPEG vs PNG vs HEIC

### Common Issues:

**Issue**: "Unsupported content type"  
**Solution**: Check console for actual types, add support if needed

**Issue**: "Could not load image from file"  
**Solution**: File might be corrupt or in unsupported format

**Issue**: Extension doesn't appear in Preview's share sheet  
**Solution**: Check Info.plist NSExtensionActivationRule includes file types

## Info.plist Configuration

Make sure your Share Extension's Info.plist includes:

```xml
<key>NSExtensionActivationRule</key>
<dict>
    <key>NSExtensionActivationSupportsImageWithMaxCount</key>
    <integer>10</integer>
    <key>NSExtensionActivationSupportsFileWithMaxCount</key>
    <integer>10</integer>
    <key>NSExtensionActivationSupportsText</key>
    <false/>
</dict>
```

The `NSExtensionActivationSupportsFileWithMaxCount` is crucial for Preview support!

## Summary

The Share Extension now supports:
- ✅ Photos app (as before)
- ✅ **Preview app (NEW!)**
- ✅ Safari
- ✅ Files app
- ✅ Mail
- ✅ Notes
- ✅ Most other apps

It handles:
- Direct image objects
- File URLs
- Raw data
- Generic URLs
- PDF files

With comprehensive logging and error handling for debugging any new sharing formats!

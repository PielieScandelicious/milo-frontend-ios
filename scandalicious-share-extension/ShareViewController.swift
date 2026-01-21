//
//  ShareViewController.swift
//  Scandalicious Share Extension
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import UIKit
import UniformTypeIdentifiers
import FirebaseCore
import FirebaseAuth

class ShareViewController: UIViewController {
    
    // MARK: - UI Components (Unified Status View)
    private var statusVC: ReceiptStatusViewController?
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Firebase if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in Share Extension")
        }
        
        // Debug: Check authentication status
        debugAuthenticationStatus()
    }
    
    // MARK: - Debug Authentication
    private func debugAuthenticationStatus() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        
        print("🔍 ========================================")
        print("🔍 Share Extension Authentication Debug")
        print("🔍 ========================================")
        
        // Check if Firebase is configured
        if FirebaseApp.app() != nil {
            print("✅ Firebase is configured")
        } else {
            print("❌ Firebase is NOT configured!")
        }
        
        // Print container path
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            print("📁 App Group Container Path:")
            print("   \(containerURL.path)")
        } else {
            print("❌ Could not get container URL for App Group!")
        }
        
        // Check Firebase Auth
        if let user = Auth.auth().currentUser {
            print("✅ Firebase user found:")
            print("   UID: \(user.uid)")
            print("   Email: \(user.email ?? "N/A")")
            print("   isAnonymous: \(user.isAnonymous)")
            
            Task {
                do {
                    let token = try await user.getIDToken()
                    print("✅ Successfully got token from Firebase")
                    print("   Token length: \(token.count)")
                    print("   Token prefix: \(token.prefix(20))...")
                } catch {
                    print("❌ Failed to get token from Firebase: \(error.localizedDescription)")
                }
            }
        } else {
            print("❌ NO Firebase user in Share Extension")
            print("   This means Firebase Auth state is not shared")
        }
        
        // Check shared storage
        print("\n📦 Checking App Group Storage:")
        print("   Identifier: \(appGroupIdentifier)")
        
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("✅ Can access shared UserDefaults")
            
            // Check for test value first
            if let testValue = sharedDefaults.string(forKey: "SCANDALICIOUS_TEST") {
                print("✅✅✅ TEST VALUE FOUND: '\(testValue)'")
                print("   This confirms we're accessing the SAME container as main app!")
            } else {
                print("❌❌❌ TEST VALUE NOT FOUND!")
                print("   This means we're NOT accessing the same container!")
            }
            
            // Check obvious key
            if let token = sharedDefaults.string(forKey: "SCANDALICIOUS_AUTH_TOKEN") {
                print("✅ Token found with obvious key!")
                print("   Token length: \(token.count)")
            }
            
            // Check primary key
            if let token = sharedDefaults.string(forKey: "firebase_auth_token") {
                print("✅ Token found in shared storage")
                print("   Token length: \(token.count)")
                print("   Token prefix: \(token.prefix(20))...")
            } else {
                print("❌ NO token in shared storage")
                print("   Key 'firebase_auth_token' is missing")
            }
            
            // Check alternative key
            if let altToken = sharedDefaults.string(forKey: "auth_token") {
                print("✅ Alternative token found (key: 'auth_token')")
                print("   Token length: \(altToken.count)")
            }
            
            // Check timestamp
            if let timestamp = sharedDefaults.object(forKey: "firebase_auth_token_timestamp") as? TimeInterval {
                let date = Date(timeIntervalSince1970: timestamp)
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                print("ℹ️  Last token save: \(formatter.string(from: date))")
            }
            
            // List all keys
            let allKeys = Array(sharedDefaults.dictionaryRepresentation().keys).sorted()
            print("\n📋 All keys in shared UserDefaults (\(allKeys.count) total):")
            
            // Print first 20 to look for our keys
            for (index, key) in allKeys.prefix(20).enumerated() {
                let value = sharedDefaults.object(forKey: key)
                let valueType = type(of: value)
                
                // Highlight our keys
                if key.contains("SCANDALICIOUS") || key.contains("firebase_auth") || key.contains("auth_token") {
                    print("   [\(index + 1)] ⭐️ \(key) = \(valueType)")
                } else {
                    print("   [\(index + 1)] \(key) = \(valueType)")
                }
            }
            
            if allKeys.count > 20 {
                print("   ... and \(allKeys.count - 20) more")
            }
            
            if allKeys.isEmpty {
                print("   ⚠️ Shared UserDefaults is EMPTY!")
            }
        } else {
            print("❌ CANNOT access shared UserDefaults")
            print("   App Group '\(appGroupIdentifier)' may not be configured")
            print("   OR the identifier is wrong")
        }
        
        print("\n🔍 ========================================")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Show initial status - just "Processing..."
        showStatus(.processing(subtitle: ""))
        
        // Start processing immediately
        processSharedContent()
    }
    
    // MARK: - Process Shared Content
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            updateStatus(error: "No content found")
            return
        }
        
        guard let itemProvider = extensionItem.attachments?.first else {
            updateStatus(error: "No attachment found")
            return
        }
        
        print("📋 Available type identifiers:")
        for identifier in itemProvider.registeredTypeIdentifiers {
            print("  - \(identifier)")
        }
        
        // Try to load in priority order
        // 1. Try image types first (most common - Photos, Safari)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            print("✅ Found UTType.image, loading...")
            loadImageFromProvider(itemProvider)
        }
        // 2. Try file URL (Preview's primary method)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            print("✅ Found UTType.fileURL, loading...")
            loadFileURL(itemProvider)
        }
        // 3. Try generic URL
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            print("✅ Found UTType.url, loading...")
            loadURLFromProvider(itemProvider)
        }
        // 4. Try PDF
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            print("✅ Found UTType.pdf, loading...")
            loadPDFFromProvider(itemProvider)
        }
        // 5. Try common image UTIs directly
        else if itemProvider.hasItemConformingToTypeIdentifier("public.jpeg") ||
                itemProvider.hasItemConformingToTypeIdentifier("public.png") ||
                itemProvider.hasItemConformingToTypeIdentifier("public.heic") {
            print("✅ Found specific image format, loading...")
            loadImageFromProvider(itemProvider)
        }
        // 6. Try public.data as last resort (can be ambiguous)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            print("✅ Found UTType.data, attempting to load as image...")
            loadDataAsImage(itemProvider)
        }
        else {
            let types = itemProvider.registeredTypeIdentifiers.joined(separator: ", ")
            updateStatus(error: "Unsupported content type. Found: \(types)")
        }
    }
    
    private func loadImageFromProvider(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.updateStatus(error: "Failed to load image: \(error.localizedDescription)")
                return
            }
            
            var image: UIImage?
            
            // Handle different image types
            if let url = item as? URL {
                // Try to load from file URL
                if let data = try? Data(contentsOf: url) {
                    image = UIImage(data: data)
                } else {
                    image = UIImage(contentsOfFile: url.path)
                }
            } else if let data = item as? Data {
                image = UIImage(data: data)
            } else if let img = item as? UIImage {
                image = img
            }
            
            guard let receiptImage = image else {
                self.updateStatus(error: "Could not load image from file")
                return
            }
            
            // Save the receipt image
            Task {
                await self.saveReceiptImage(receiptImage)
            }
        }
    }
    
    private func loadPDFFromProvider(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.updateStatus(error: "Failed to load PDF: \(error.localizedDescription)")
                return
            }
            
            guard let url = item as? URL else {
                self.updateStatus(error: "Could not load PDF from file")
                return
            }
            
            // Upload PDF directly without conversion
            Task {
                await self.uploadPDFReceipt(from: url)
            }
        }
    }
    
    private func loadURLFromProvider(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.updateStatus(error: "Failed to load URL: \(error.localizedDescription)")
                return
            }
            
            guard let url = item as? URL else {
                self.updateStatus(error: "Invalid URL")
                return
            }
            
            print("📂 Loading from URL: \(url)")
            
            // Try to load image from URL
            var image: UIImage?
            if let data = try? Data(contentsOf: url) {
                image = UIImage(data: data)
            }
            
            guard let receiptImage = image else {
                self.updateStatus(error: "Could not load image from URL")
                return
            }
            
            Task {
                await self.saveReceiptImage(receiptImage)
            }
        }
    }
    
    // MARK: - Load File URL (for Preview app)
    private func loadFileURL(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to load file URL: \(error)")
                self.updateStatus(error: "Failed to load file: \(error.localizedDescription)")
                return
            }
            
            guard let fileURL = item as? URL else {
                print("❌ Item is not a URL")
                self.updateStatus(error: "Invalid file URL")
                return
            }
            
            print("📂 File URL: \(fileURL)")
            print("📂 Path extension: \(fileURL.pathExtension)")
            
            // Check if it's an image file
            let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "tif"]
            let pathExtension = fileURL.pathExtension.lowercased()
            
            if imageExtensions.contains(pathExtension) {
                // Try to load as image
                if let data = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: data) {
                    print("✅ Loaded image from file URL")
                    Task {
                        await self.saveReceiptImage(image)
                    }
                } else {
                    print("❌ Could not create image from file data")
                    self.updateStatus(error: "Could not load image from file")
                }
            } else if pathExtension == "pdf" {
                // Upload PDF directly without conversion
                print("📄 Uploading PDF directly...")
                Task {
                    await self.uploadPDFReceipt(from: fileURL)
                }
            } else {
                print("❌ Unsupported file type: \(pathExtension)")
                self.updateStatus(error: "Unsupported file type: .\(pathExtension)")
            }
        }
    }
    
    // MARK: - Load Data as Image (for Preview app)
    private func loadDataAsImage(_ itemProvider: NSItemProvider) {
        // Try loading as file URL first within the data type
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            print("📋 Data type also has fileURL, trying that instead...")
            loadFileURL(itemProvider)
            return
        }
        
        itemProvider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to load data: \(error)")
                // Try loading as image type as fallback
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    print("🔄 Retrying as image type...")
                    self.loadImageFromProvider(itemProvider)
                    return
                }
                self.updateStatus(error: "Failed to load data: \(error.localizedDescription)")
                return
            }
            
            print("📦 Data item type: \(type(of: item))")
            
            var imageData: Data?
            var imageFromItem: UIImage?
            
            // Try different ways to extract the image
            if let data = item as? Data {
                print("✅ Got Data directly (\(data.count) bytes)")
                imageData = data
            } else if let url = item as? URL {
                print("📂 Data provided as URL: \(url)")
                print("📂 URL scheme: \(url.scheme ?? "none")")
                
                // Check if it's a file URL
                if url.isFileURL {
                    // Try to read the file
                    if let data = try? Data(contentsOf: url) {
                        print("✅ Read \(data.count) bytes from file URL")
                        imageData = data
                    } else {
                        print("❌ Could not read data from file URL")
                    }
                } else {
                    // Try to download from URL
                    if let data = try? Data(contentsOf: url) {
                        print("✅ Downloaded \(data.count) bytes from URL")
                        imageData = data
                    }
                }
            } else if let image = item as? UIImage {
                print("✅ Got UIImage directly")
                imageFromItem = image
            }
            
            // If we got a UIImage directly, use it
            if let image = imageFromItem {
                print("✅ Using UIImage directly: \(image.size)")
                Task {
                    await self.saveReceiptImage(image)
                }
                return
            }
            
            // Try to create image from data
            guard let data = imageData else {
                print("❌ Could not extract data from item")
                // Try one more time with image type
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    print("🔄 Retrying as UTType.image...")
                    self.loadImageFromProvider(itemProvider)
                    return
                }
                self.updateStatus(error: "Could not extract image data")
                return
            }
            
            // Try to create UIImage from data
            if let image = UIImage(data: data) {
                print("✅ Created image from data: \(image.size)")
                Task {
                    await self.saveReceiptImage(image)
                }
            } else {
                print("❌ Could not create image from data (\(data.count) bytes)")
                print("📋 Data header (first 16 bytes): \(data.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
                
                // One last attempt - try all available image type identifiers
                for identifier in itemProvider.registeredTypeIdentifiers {
                    if identifier.contains("image") || identifier.contains("jpeg") || identifier.contains("png") {
                        print("🔄 Found possible image identifier: \(identifier), trying that...")
                        self.loadImageFromProvider(itemProvider)
                        return
                    }
                }
                
                self.updateStatus(error: "Could not create image from data")
            }
        }
    }
    
    private func convertPDFToImage(url: URL) -> UIImage? {
        print("📄 Converting PDF at: \(url.path)")
        
        guard let document = CGPDFDocument(url as CFURL) else {
            print("❌ Could not create CGPDFDocument from URL")
            return nil
        }
        
        print("📄 PDF has \(document.numberOfPages) pages")
        
        guard let page = document.page(at: 1) else {
            print("❌ Could not get first page of PDF")
            return nil
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        print("📄 PDF page size: \(pageRect.size)")
        
        // Scale down if the PDF is too large (to prevent memory issues)
        let maxDimension: CGFloat = 2048.0  // Maximum width or height
        var renderSize = pageRect.size
        
        if renderSize.width > maxDimension || renderSize.height > maxDimension {
            let scaleFactor = maxDimension / max(renderSize.width, renderSize.height)
            renderSize = CGSize(width: renderSize.width * scaleFactor, 
                               height: renderSize.height * scaleFactor)
            print("📄 Scaling down to: \(renderSize)")
        }
        
        // Create the image at the (possibly scaled) size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Don't use screen scale, we're controlling size ourselves
        
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        
        let image = renderer.image { ctx in
            // Fill with white background
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: renderSize))
            
            // Save the graphics state
            ctx.cgContext.saveGState()
            
            // Transform to render the PDF correctly
            ctx.cgContext.translateBy(x: 0, y: renderSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            // Scale the PDF to fit our render size
            let scaleX = renderSize.width / pageRect.width
            let scaleY = renderSize.height / pageRect.height
            ctx.cgContext.scaleBy(x: scaleX, y: scaleY)
            
            // Render the PDF
            ctx.cgContext.drawPDFPage(page)
            
            // Restore the graphics state
            ctx.cgContext.restoreGState()
        }
        
        print("✅ PDF converted to image: \(image.size)")
        return image
    }
    
    // MARK: - Upload PDF Receipt
    private func uploadPDFReceipt(from pdfURL: URL) async {
        print("📄 uploadPDFReceipt started for: \(pdfURL)")
        
        do {
            // Upload PDF directly to API
            print("☁️ Uploading PDF receipt to server...")
            let response = try await ReceiptUploadService.shared.uploadPDFReceipt(from: pdfURL)
            print("✅ PDF uploaded successfully - Receipt ID: \(response.receiptId)")
            
            // Show success
            updateStatus(.success(message: ""))

            // Signal main app that it needs to refresh data
            signalMainAppToRefresh()

            // Keep success visible
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            // Complete the request
            await MainActor.run {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }

            print("✅ PDF upload completed successfully")
            
        } catch let error as ReceiptUploadError {
            print("❌ ReceiptUploadError: \(error.localizedDescription)")
            updateStatus(.failed(message: getUserFriendlyError(from: error), canRetry: false))
        } catch let error as ReceiptError {
            print("❌ ReceiptError: \(error.localizedDescription)")
            updateStatus(.failed(message: getUserFriendlyError(from: error), canRetry: false))
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            updateStatus(.failed(message: "Unable to upload PDF. Please try again.", canRetry: false))
        }
    }
    
    // MARK: - Upload Receipt Image
    private func saveReceiptImage(_ image: UIImage) async {
        print("💾 uploadReceiptImage started")
        
        do {
            // Validate image
            guard image.size.width > 0 && image.size.height > 0 else {
                throw ReceiptError.invalidImage
            }
            
            print("☁️ Uploading receipt to server...")
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            print("✅ Receipt uploaded successfully - Receipt ID: \(response.receiptId)")
            
            // Show success
            updateStatus(.success(message: ""))

            // Signal main app that it needs to refresh data
            signalMainAppToRefresh()

            print("✅ Success shown, waiting 1.5 seconds...")

            // Keep success visible
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            // Complete the request
            await MainActor.run {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }

            print("✅ Extension completed successfully")
            
        } catch let error as ReceiptError {
            print("❌ ReceiptError: \(error.localizedDescription)")
            updateStatus(.failed(message: getUserFriendlyError(from: error), canRetry: false))
        } catch let error as ReceiptUploadError {
            print("❌ ReceiptUploadError: \(error.localizedDescription)")
            updateStatus(.failed(message: getUserFriendlyError(from: error), canRetry: false))
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            updateStatus(.failed(message: "Unable to upload receipt. Please try again.", canRetry: false))
        }
    }

    // MARK: - Status Management
    
    private func showStatus(_ status: ReceiptStatusType) {
        DispatchQueue.main.async {
            if self.statusVC == nil {
                let vc = ReceiptStatusViewController(
                    status: status,
                    onRetry: nil,
                    onDismiss: { [weak self] in
                        self?.extensionContext?.cancelRequest(withError: NSError(
                            domain: "ShareExtension",
                            code: 1,
                            userInfo: nil
                        ))
                    }
                )
                vc.modalPresentationStyle = .overFullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
                self.statusVC = vc
            } else {
                self.statusVC?.updateStatus(status)
            }
        }
    }
    
    private func updateStatus(_ newStatus: ReceiptStatusType) {
        showStatus(newStatus)
    }
    
    // MARK: - Signal Main App to Refresh

    /// Saves a timestamp to shared UserDefaults to signal the main app that new data is available
    private func signalMainAppToRefresh() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Could not access shared UserDefaults to signal refresh")
            print("⚠️ App Group identifier: \(appGroupIdentifier)")
            return
        }

        // Save current timestamp - main app will check this when it becomes active
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults.set(timestamp, forKey: "receipt_upload_timestamp")
        sharedDefaults.synchronize()

        // Verify the write succeeded
        let verifyTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
        print("✅ Signaled main app to refresh")
        print("   Written timestamp: \(timestamp)")
        print("   Verified timestamp: \(verifyTimestamp)")
        print("   Write successful: \(timestamp == verifyTimestamp)")
    }

    // MARK: - User-Friendly Error Messages

    private func getUserFriendlyError(from error: Error) -> String {
        if let receiptError = error as? ReceiptError {
            switch receiptError {
            case .invalidImage:
                return "The image appears to be invalid. Please try again."
            case .uploadFailed:
                return "Unable to upload receipt. Please try again."
            }
        }
        
        if let uploadError = error as? ReceiptUploadError {
            switch uploadError {
            case .noImage:
                return "No image provided. Please try again."
            case .invalidResponse:
                return "Unable to process receipt. Please try again."
            case .noAuthToken:
                return "Please sign in again in the main app."
            case .serverError:
                return "Unable to upload receipt. Please try again later."
            case .networkError:
                return "Please check your internet connection and try again."
            }
        }
        
        // Generic user-friendly message
        return "Unable to upload receipt. Please try again."
    }
    
    // MARK: - Update UI Status (Legacy - kept for error cases)
    
    private func updateStatus(message: String) {
        updateStatus(.uploading(subtitle: message))
    }
    
    private func updateStatus(error: String) {
        // Convert to user-friendly message
        let friendlyMessage = error.contains("Server error:") || error.contains("HTTP") || error.contains("URLSession")
            ? "Unable to upload receipt. Please try again later."
            : error
        
        updateStatus(.failed(message: friendlyMessage, canRetry: false))
    }
}

// MARK: - Supporting Types
enum ReceiptError: LocalizedError {
    case invalidImage
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image appears to be invalid or empty"
        case .uploadFailed:
            return "Failed to upload receipt to server"
        }
    }
}

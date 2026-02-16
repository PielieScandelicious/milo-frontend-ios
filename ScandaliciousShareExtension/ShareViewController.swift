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
        }

        // Debug: Check authentication status
        debugAuthenticationStatus()
    }

    // MARK: - Debug Authentication
    private func debugAuthenticationStatus() {
        // Authentication debugging disabled for production
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Start processing immediately - success will be shown once upload begins
        processSharedContent()
    }

    // MARK: - Rate Limit Check

    /// Decrements the rate limit locally after showing success to prevent stale data issues
    private func decrementRateLimitLocally() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        // Get the current user ID - try Firebase Auth first, then fall back to shared storage
        let userId: String
        if let firebaseUserId = Auth.auth().currentUser?.uid {
            userId = firebaseUserId
        } else if let storedUserId = sharedDefaults.string(forKey: "rateLimit_currentUserId") {
            userId = storedUserId
        } else {
            return
        }

        // Build the specific key for this user (matching RateLimitManager's key format)
        let receiptsRemainingKey = "rateLimit_\(userId)_receiptsRemaining"

        // Check if the key exists
        guard sharedDefaults.object(forKey: receiptsRemainingKey) != nil else {
            return
        }

        let currentValue = sharedDefaults.integer(forKey: receiptsRemainingKey)
        let newValue = max(0, currentValue - 1)
        sharedDefaults.set(newValue, forKey: receiptsRemainingKey)
        sharedDefaults.synchronize()
    }

    /// Checks if the user has remaining receipt uploads by reading from shared UserDefaults
    private func checkRateLimitFromSharedStorage() -> (canUpload: Bool, message: String?) {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"

        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            // If we can't check, allow the upload (backend will reject if needed)
            return (true, nil)
        }

        // Get the current user ID - try Firebase Auth first, then fall back to shared storage
        let userId: String
        if let firebaseUserId = Auth.auth().currentUser?.uid {
            userId = firebaseUserId
        } else if let storedUserId = sharedDefaults.string(forKey: "rateLimit_currentUserId") {
            userId = storedUserId
        } else {
            // If we can't identify the user, allow the upload (backend will reject if needed)
            return (true, nil)
        }

        // Build the specific key for this user (matching RateLimitManager's key format)
        let receiptsRemainingKey = "rateLimit_\(userId)_receiptsRemaining"
        let daysUntilResetKey = "rateLimit_\(userId)_daysUntilReset"

        // Check if the key exists - UserDefaults.integer(forKey:) returns 0 for non-existent keys
        guard sharedDefaults.object(forKey: receiptsRemainingKey) != nil else {
            // If no rate limit data is saved, allow the upload (backend will reject if needed)
            return (true, nil)
        }

        let receiptsRemaining = sharedDefaults.integer(forKey: receiptsRemainingKey)
        let daysUntilReset = sharedDefaults.integer(forKey: daysUntilResetKey)

        // If receiptsRemaining is 0, block the upload
        if receiptsRemaining <= 0 {
            let message: String
            if daysUntilReset > 0 {
                message = "You've reached your monthly upload limit.\n\nYour limit resets in \(daysUntilReset) day\(daysUntilReset == 1 ? "" : "s")."
            } else {
                message = "You've reached your monthly upload limit.\n\nYour limit resets soon."
            }
            return (false, message)
        }

        return (true, nil)
    }

    // MARK: - Process Shared Content
    private func processSharedContent() {
        // Check rate limit before processing
        let rateLimitCheck = checkRateLimitFromSharedStorage()
        if !rateLimitCheck.canUpload {
            updateStatus(.failed(message: rateLimitCheck.message ?? "Upload limit reached for this month.", canRetry: false))
            return
        }

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            updateStatus(error: "No content found")
            return
        }

        guard let itemProvider = extensionItem.attachments?.first else {
            updateStatus(error: "No attachment found")
            return
        }

        // Try to load in priority order
        // 1. Try image types first (most common - Photos, Safari)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            loadImageFromProvider(itemProvider)
        }
        // 2. Try file URL (Preview's primary method)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            loadFileURL(itemProvider)
        }
        // 3. Try generic URL
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            loadURLFromProvider(itemProvider)
        }
        // 4. Try PDF
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            loadPDFFromProvider(itemProvider)
        }
        // 5. Try common image UTIs directly
        else if itemProvider.hasItemConformingToTypeIdentifier("public.jpeg") ||
                itemProvider.hasItemConformingToTypeIdentifier("public.png") ||
                itemProvider.hasItemConformingToTypeIdentifier("public.heic") ||
                itemProvider.hasItemConformingToTypeIdentifier("org.webmproject.webp") ||
                itemProvider.hasItemConformingToTypeIdentifier("public.webp") {
            loadImageFromProvider(itemProvider)
        }
        // 6. Try public.data as last resort (can be ambiguous)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            loadDataAsImage(itemProvider)
        }
        // 7. Try to load whatever type is available as a file
        else if let firstType = itemProvider.registeredTypeIdentifiers.first {
            loadGenericContent(itemProvider, typeIdentifier: firstType)
        }
        else {
            updateStatus(error: "No supported content found.\n\nSupported: images (JPG, PNG, HEIC, WebP, etc.) and PDF")
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

            // Handle PDF provided as URL
            if let url = item as? URL {
                Task {
                    await self.uploadPDFReceipt(from: url)
                }
                return
            }

            // Handle PDF provided as Data
            if let pdfData = item as? Data {
                // Save to temp file and upload
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("receipt_\(UUID().uuidString).pdf")
                do {
                    try pdfData.write(to: tempURL)
                    Task {
                        await self.uploadPDFReceipt(from: tempURL)
                    }
                } catch {
                    self.updateStatus(error: "Could not save PDF file")
                }
                return
            }

            // Unknown format
            self.updateStatus(error: "Could not load PDF from file")
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
                self.updateStatus(error: "Failed to load file: \(error.localizedDescription)")
                return
            }

            guard let fileURL = item as? URL else {
                self.updateStatus(error: "Invalid file URL")
                return
            }

            // Check file type and handle accordingly
            let pathExtension = fileURL.pathExtension.lowercased()

            // Supported image extensions (all formats UIImage can handle)
            let imageExtensions = [
                "jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "tif",
                "webp",           // WebP images
                "ico",            // Icon files
                "dng", "cr2", "nef", "arw", "orf", "rw2",  // RAW camera formats
                "svg"             // SVG (limited support via UIImage)
            ]

            if imageExtensions.contains(pathExtension) {
                // Try to load as image
                self.loadImageFromFileURL(fileURL)
            } else if pathExtension == "pdf" {
                // Upload PDF directly without conversion
                Task {
                    await self.uploadPDFReceipt(from: fileURL)
                }
            } else {
                // For unknown extensions, try to load as image first (many image formats work)
                self.loadImageFromFileURL(fileURL, fallbackToPDF: true)
            }
        }
    }

    // MARK: - Load Data as Image (for Preview app)
    private func loadDataAsImage(_ itemProvider: NSItemProvider) {
        // Try loading as file URL first within the data type
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            loadFileURL(itemProvider)
            return
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }

            if let error = error {
                // Try loading as image type as fallback
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    self.loadImageFromProvider(itemProvider)
                    return
                }
                self.updateStatus(error: "Failed to load data: \(error.localizedDescription)")
                return
            }

            var imageData: Data?
            var imageFromItem: UIImage?

            // Try different ways to extract the image
            if let data = item as? Data {
                imageData = data
            } else if let url = item as? URL {
                // Check if it's a file URL
                if url.isFileURL {
                    // Try to read the file
                    if let data = try? Data(contentsOf: url) {
                        imageData = data
                    }
                } else {
                    // Try to download from URL
                    if let data = try? Data(contentsOf: url) {
                        imageData = data
                    }
                }
            } else if let image = item as? UIImage {
                imageFromItem = image
            }

            // If we got a UIImage directly, use it
            if let image = imageFromItem {
                Task {
                    await self.saveReceiptImage(image)
                }
                return
            }

            // Try to create image from data
            guard let data = imageData else {
                // Try one more time with image type
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    self.loadImageFromProvider(itemProvider)
                    return
                }
                self.updateStatus(error: "Could not extract image data")
                return
            }

            // Try to create UIImage from data
            if let image = UIImage(data: data) {
                Task {
                    await self.saveReceiptImage(image)
                }
            } else {
                // One last attempt - try all available image type identifiers
                for identifier in itemProvider.registeredTypeIdentifiers {
                    if identifier.contains("image") || identifier.contains("jpeg") || identifier.contains("png") {
                        self.loadImageFromProvider(itemProvider)
                        return
                    }
                }

                self.updateStatus(error: "Could not create image from data")
            }
        }
    }

    // MARK: - Load Generic Content (fallback for unknown types)
    private func loadGenericContent(_ itemProvider: NSItemProvider, typeIdentifier: String) {
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }

            if let error = error {
                self.updateStatus(error: "Could not load file.\n\nSupported: images and PDF")
                return
            }

            // Try to extract data from the item
            var data: Data?

            if let url = item as? URL {
                data = try? Data(contentsOf: url)

                // Also try loading directly via the file URL handler
                if url.isFileURL {
                    self.loadImageFromFileURL(url, fallbackToPDF: true)
                    return
                }
            } else if let itemData = item as? Data {
                data = itemData
            } else if let image = item as? UIImage {
                Task {
                    await self.saveReceiptImage(image)
                }
                return
            }

            // Try to create image from data
            if let data = data {
                if let image = UIImage(data: data) {
                    Task {
                        await self.saveReceiptImage(image)
                    }
                    return
                }

                // Check if it's a PDF
                if data.count >= 4 {
                    let header = data.prefix(4)
                    if header.elementsEqual([0x25, 0x50, 0x44, 0x46]) {  // %PDF
                        // Save to temp file and upload
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("receipt_\(UUID().uuidString).pdf")
                        do {
                            try data.write(to: tempURL)
                            Task {
                                await self.uploadPDFReceipt(from: tempURL)
                            }
                            return
                        } catch {
                            // Failed to write temp PDF
                        }
                    }
                }
            }

            // If we got here, we couldn't handle the content
            self.updateStatus(error: "Unsupported file type.\n\nSupported: images (JPG, PNG, HEIC, WebP, etc.) and PDF")
        }
    }

    // MARK: - Load Image from File URL
    private func loadImageFromFileURL(_ fileURL: URL, fallbackToPDF: Bool = false) {
        // Try to load as image
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            Task {
                await self.saveReceiptImage(image)
            }
            return
        }

        // If image loading failed and fallback is enabled, try PDF
        if fallbackToPDF {
            if let pdfData = try? Data(contentsOf: fileURL),
               pdfData.count >= 4 {
                // Check for PDF magic bytes (%PDF)
                let header = pdfData.prefix(4)
                if header.elementsEqual([0x25, 0x50, 0x44, 0x46]) {  // %PDF
                    Task {
                        await self.uploadPDFReceipt(from: fileURL)
                    }
                    return
                }
            }

            // Neither image nor PDF worked
            let ext = fileURL.pathExtension.lowercased()
            self.updateStatus(error: "Unsupported file type: .\(ext)\n\nSupported: images (JPG, PNG, HEIC, WebP, etc.) and PDF")
        } else {
            self.updateStatus(error: "Could not load image from file")
        }
    }

    private func convertPDFToImage(url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL) else {
            return nil
        }

        guard let page = document.page(at: 1) else {
            return nil
        }

        let pageRect = page.getBoxRect(.mediaBox)

        // Scale down if the PDF is too large (to prevent memory issues)
        let maxDimension: CGFloat = 2048.0  // Maximum width or height
        var renderSize = pageRect.size

        if renderSize.width > maxDimension || renderSize.height > maxDimension {
            let scaleFactor = maxDimension / max(renderSize.width, renderSize.height)
            renderSize = CGSize(width: renderSize.width * scaleFactor,
                               height: renderSize.height * scaleFactor)
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

        return image
    }

    // MARK: - Upload PDF Receipt
    private func uploadPDFReceipt(from pdfURL: URL) async {
        // Read PDF data first to ensure it's valid
        guard let pdfData = try? Data(contentsOf: pdfURL), !pdfData.isEmpty else {
            updateStatus(.failed(message: "Could not read PDF file.", canRetry: false))
            return
        }

        // Show success immediately for instant feedback
        updateStatus(.success(message: ""))

        // Signal main app that it needs to refresh data
        signalMainAppToRefresh()

        // Decrement rate limit locally to prevent stale data allowing duplicate uploads
        decrementRateLimitLocally()

        // Start upload with expiring activity to ensure it completes
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Uploading PDF receipt") { expired in
            if expired {
                return
            }

            Task {
                do {
                    let result = try await ReceiptUploadService.shared.uploadPDFReceipt(from: pdfURL)
                    if case .accepted(let accepted) = result {
                        self.persistProcessingReceipt(receiptId: accepted.receiptId, filename: accepted.filename)
                    }
                } catch {
                    // Error is logged but not shown - user already saw success
                }
            }
        }

        // Keep success visible briefly for the animation (matches scan view timing)
        try? await Task.sleep(nanoseconds: 1_800_000_000) // 1.8 seconds

        // Complete the request
        await MainActor.run {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - Upload Receipt Image
    private func saveReceiptImage(_ image: UIImage) async {
        // Validate image
        guard image.size.width > 0 && image.size.height > 0 else {
            updateStatus(.failed(message: "The image appears to be invalid. Please try again.", canRetry: false))
            return
        }

        // Show success immediately for instant feedback
        updateStatus(.success(message: ""))

        // Signal main app that it needs to refresh data
        signalMainAppToRefresh()

        // Decrement rate limit locally to prevent stale data allowing duplicate uploads
        decrementRateLimitLocally()

        // Start upload with expiring activity to ensure it completes
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Uploading receipt") { expired in
            if expired {
                return
            }

            Task {
                do {
                    let result = try await ReceiptUploadService.shared.uploadReceipt(image: image)
                    if case .accepted(let accepted) = result {
                        self.persistProcessingReceipt(receiptId: accepted.receiptId, filename: accepted.filename)
                    }
                } catch {
                    // Error is logged but not shown - user already saw success
                }
            }
        }

        // Keep success visible briefly for the animation (matches scan view timing)
        try? await Task.sleep(nanoseconds: 1_800_000_000) // 1.8 seconds

        // Complete the request
        await MainActor.run {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - Status Management

    private func showStatus(_ status: ReceiptStatusType) {
        DispatchQueue.main.async {
            if self.statusVC == nil {
                self.presentStatusViewController(with: status)
            } else {
                self.statusVC?.updateStatus(status)
            }
        }
    }

    private func presentStatusViewController(with status: ReceiptStatusType, retryCount: Int = 0) {
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

        // Ensure view is in window hierarchy before presenting
        // This fixes the issue where the dialogue doesn't show when rate limit is 0
        guard self.view.window != nil else {
            // View not ready yet, retry after a short delay (max 5 retries = 0.5 seconds)
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.presentStatusViewController(with: status, retryCount: retryCount + 1)
                }
            }
            return
        }

        self.present(vc, animated: true)
        self.statusVC = vc
    }

    private func updateStatus(_ newStatus: ReceiptStatusType) {
        showStatus(newStatus)
    }

    // MARK: - Persist Processing Receipt for Main App

    /// Saves a processing receipt to app group UserDefaults so the main app's
    /// ReceiptProcessingManager can pick it up and start polling.
    private func persistProcessingReceipt(receiptId: String, filename: String) {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let storageKey = "activeProcessingReceipts"

        // Read existing array
        var receipts: [ProcessingReceipt] = []
        if let data = sharedDefaults.data(forKey: storageKey),
           let existing = try? JSONDecoder().decode([ProcessingReceipt].self, from: data) {
            receipts = existing
        }

        // Append new receipt (avoid duplicates)
        guard !receipts.contains(where: { $0.id == receiptId }) else { return }

        let receipt = ProcessingReceipt(
            id: receiptId,
            filename: filename,
            startedAt: Date(),
            status: .pending,
            storeName: nil,
            totalAmount: nil,
            itemsCount: 0,
            errorMessage: nil,
            detectedDate: nil,
            completedAt: nil
        )
        receipts.append(receipt)

        if let encoded = try? JSONEncoder().encode(receipts) {
            sharedDefaults.set(encoded, forKey: storageKey)
            sharedDefaults.synchronize()
        }
    }

    // MARK: - Signal Main App to Refresh

    /// Saves a timestamp to shared UserDefaults to signal the main app that new data is available
    private func signalMainAppToRefresh() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        // Save current timestamp - main app will check this when it becomes active
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults.set(timestamp, forKey: "receipt_upload_timestamp")
        sharedDefaults.synchronize()
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
            case .rateLimitExceeded(let error):
                let daysUntilReset = Calendar.current.dateComponents([.day], from: Date(), to: error.details.periodEndDate).day ?? 0
                if daysUntilReset > 0 {
                    return "Upload limit reached. Resets in \(daysUntilReset) day\(daysUntilReset == 1 ? "" : "s")."
                } else {
                    return "Upload limit reached for this month."
                }
            case .deleteFailed:
                return "Unable to delete receipt. Please try again."
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

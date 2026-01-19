//
//  ShareViewController.swift
//  Dobby Share Extension
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Saving Receipt..."
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let storeLabel: UILabel = {
        let label = UILabel()
        label.text = "Saving to your library..."
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    private let appGroupIdentifier = "group.com.dobby.app"
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedContent()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(storeLabel)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            storeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            storeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            storeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            activityIndicator.topAnchor.constraint(equalTo: storeLabel.bottomAnchor, constant: 24),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
        ])
        
        activityIndicator.startAnimating()
    }
    
    // MARK: - Process Shared Content
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            updateStatus(error: "No content found")
            completeRequest(withError: NSError(domain: "ShareExtension", code: 1, userInfo: nil))
            return
        }
        
        guard let itemProvider = extensionItem.attachments?.first else {
            updateStatus(error: "No attachment found")
            completeRequest(withError: NSError(domain: "ShareExtension", code: 1, userInfo: nil))
            return
        }
        
        // Try to load as image first
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            loadImageFromProvider(itemProvider)
        } 
        // Try PDF (some receipt apps share as PDF)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            loadPDFFromProvider(itemProvider)
        }
        // Try URL (might be a file URL to an image)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            loadURLFromProvider(itemProvider)
        }
        else {
            updateStatus(error: "Unsupported content type. Please share an image.")
            completeRequest(withError: NSError(domain: "ShareExtension", code: 3, userInfo: nil))
        }
    }
    
    private func loadImageFromProvider(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.updateStatus(error: "Failed to load image: \(error.localizedDescription)")
                self.completeRequest(withError: error)
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
                self.completeRequest(withError: NSError(domain: "ShareExtension", code: 2, userInfo: nil))
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
                self.completeRequest(withError: error)
                return
            }
            
            guard let url = item as? URL,
                  let image = self.convertPDFToImage(url: url) else {
                self.updateStatus(error: "Could not convert PDF to image")
                self.completeRequest(withError: NSError(domain: "ShareExtension", code: 4, userInfo: nil))
                return
            }
            
            Task {
                await self.saveReceiptImage(image)
            }
        }
    }
    
    private func loadURLFromProvider(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.updateStatus(error: "Failed to load URL: \(error.localizedDescription)")
                self.completeRequest(withError: error)
                return
            }
            
            guard let url = item as? URL else {
                self.updateStatus(error: "Invalid URL")
                self.completeRequest(withError: NSError(domain: "ShareExtension", code: 5, userInfo: nil))
                return
            }
            
            // Try to load image from URL
            var image: UIImage?
            if let data = try? Data(contentsOf: url) {
                image = UIImage(data: data)
            }
            
            guard let receiptImage = image else {
                self.updateStatus(error: "Could not load image from URL")
                self.completeRequest(withError: NSError(domain: "ShareExtension", code: 6, userInfo: nil))
                return
            }
            
            Task {
                await self.saveReceiptImage(receiptImage)
            }
        }
    }
    
    private func convertPDFToImage(url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else {
            return nil
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.drawPDFPage(page)
        }
        
        return image
    }
    
    // MARK: - Save Receipt Image
    private func saveReceiptImage(_ image: UIImage) async {
        do {
            // Save receipt image to shared storage
            updateStatus(message: "Saving receipt...")
            
            // Validate image
            guard image.size.width > 0 && image.size.height > 0 else {
                throw ReceiptError.invalidImage
            }
            
            let savedPath = try saveReceipt(image: image)
            
            // Notify main app
            notifyMainApp(imagePath: savedPath)
            
            // Success!
            updateStatus(success: "Receipt saved successfully!")
            
            // Complete after a short delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            completeRequest(withError: nil)
            
        } catch let error as ReceiptError {
            updateStatus(error: error.errorDescription ?? "Unknown error")
            completeRequest(withError: error)
        } catch {
            updateStatus(error: "Failed to save: \(error.localizedDescription)")
            completeRequest(withError: error)
        }
    }

    
    // MARK: - Save Receipt
    private func saveReceipt(image: UIImage) throws -> String {
        // Get shared container directory
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Failed to get App Group container URL")
            throw ReceiptError.appGroupNotFound
        }
        
        print("✅ App Group container: \(containerURL.path)")
        
        // Create receipts directory
        let receiptsURL = containerURL.appendingPathComponent("receipts")
        
        do {
            try FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true, attributes: nil)
            print("✅ Receipts directory created/verified: \(receiptsURL.path)")
        } catch {
            print("❌ Failed to create directory: \(error)")
            throw error
        }
        
        // Generate unique filename with milliseconds for uniqueness
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let milliseconds = Int(Date().timeIntervalSince1970 * 1000) % 1000
        let filename = "receipt_\(timestamp)_\(milliseconds).jpg"
        let fileURL = receiptsURL.appendingPathComponent(filename)
        
        print("📝 Saving to: \(fileURL.path)")
        
        // Save image with error handling
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to compress image")
            throw ReceiptError.imageCompressionFailed
        }
        
        print("✅ Image compressed: \(imageData.count) bytes")
        
        do {
            try imageData.write(to: fileURL, options: .atomic)
            print("✅ File written successfully")
        } catch {
            print("❌ Failed to write file: \(error)")
            throw ReceiptError.fileWriteFailed
        }
        
        // Verify file was written
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("✅ File verified at: \(fileURL.path)")
        } else {
            print("❌ File does not exist after write")
            throw ReceiptError.fileWriteFailed
        }
        
        return fileURL.path
    }
    
    // MARK: - Notify Main App
    private func notifyMainApp(imagePath: String) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        
        // Store latest receipt info
        let receiptInfo: [String: Any] = [
            "imagePath": imagePath,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Get existing receipts
        var receipts = sharedDefaults.array(forKey: "pendingReceipts") as? [[String: Any]] ?? []
        receipts.append(receiptInfo)
        
        // Save updated receipts
        sharedDefaults.set(receipts, forKey: "pendingReceipts")
        sharedDefaults.synchronize()
    }
    
    // MARK: - Update UI Status
    private func updateStatus(message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
        }
    }
    
    private func updateStatus(error: String) {
        DispatchQueue.main.async {
            self.titleLabel.text = "Error"
            self.statusLabel.text = error
            self.statusLabel.textColor = .systemRed
            self.activityIndicator.stopAnimating()
        }
    }
    
    private func updateStatus(success: String) {
        DispatchQueue.main.async {
            self.titleLabel.text = "✓ Success"
            self.statusLabel.text = success
            self.statusLabel.textColor = .systemGreen
            self.activityIndicator.stopAnimating()
        }
    }
    
    // MARK: - Complete Request
    private func completeRequest(withError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.extensionContext?.cancelRequest(withError: error)
            } else {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
}

// MARK: - Supporting Types
enum ReceiptError: LocalizedError {
    case invalidImage
    case appGroupNotFound
    case imageCompressionFailed
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image appears to be invalid or empty"
        case .appGroupNotFound:
            return "App configuration error. Please reinstall the app."
        case .imageCompressionFailed:
            return "Could not compress the image"
        case .fileWriteFailed:
            return "Could not save the file. Check storage permissions."
        }
    }
}

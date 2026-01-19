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
    
    private let checkmarkView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
        imageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0
        return imageView
    }()
    
    private let imagePreview: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 8
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.separator.cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0
        return imageView
    }()
    
    // MARK: - Properties
    private let appGroupIdentifier = "group.com.dobby.app"
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Animate in the container
        animateIn()
        
        // Start processing after animation begins
        Task {
            // Small delay to ensure animation is visible
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            processSharedContent()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0)
        
        view.addSubview(containerView)
        containerView.addSubview(imagePreview)
        containerView.addSubview(titleLabel)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(checkmarkView)
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            imagePreview.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            imagePreview.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imagePreview.widthAnchor.constraint(equalToConstant: 80),
            imagePreview.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imagePreview.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            activityIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            checkmarkView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            checkmarkView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 80),
            checkmarkView.heightAnchor.constraint(equalToConstant: 80),
            
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
        ])
        
        // Start with container hidden for animation
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        activityIndicator.startAnimating()
    }
    
    // MARK: - Animations
    private func animateIn() {
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
    }
    
    // MARK: - Process Shared Content
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            updateStatus(error: "No content found")
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 1, userInfo: nil))
                }
            }
            return
        }
        
        guard let itemProvider = extensionItem.attachments?.first else {
            updateStatus(error: "No attachment found")
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 1, userInfo: nil))
                }
            }
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
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 3, userInfo: nil))
                }
            }
        }
    }
    
    private func loadImageFromProvider(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.updateStatus(error: "Failed to load image: \(error.localizedDescription)")
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: error)
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 2, userInfo: nil))
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: error)
                    }
                }
                return
            }
            
            guard let url = item as? URL,
                  let image = self.convertPDFToImage(url: url) else {
                self.updateStatus(error: "Could not convert PDF to image")
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 4, userInfo: nil))
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: error)
                    }
                }
                return
            }
            
            guard let url = item as? URL else {
                self.updateStatus(error: "Invalid URL")
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 5, userInfo: nil))
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 6, userInfo: nil))
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: error)
                    }
                }
                return
            }
            
            guard let fileURL = item as? URL else {
                print("❌ Item is not a URL")
                self.updateStatus(error: "Invalid file URL")
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 7, userInfo: nil))
                    }
                }
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
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 8, userInfo: nil))
                        }
                    }
                }
            } else if pathExtension == "pdf" {
                // Try to convert PDF
                print("🔄 Attempting to convert PDF to image...")
                if let pdfImage = self.convertPDFToImage(url: fileURL) {
                    print("✅ Converted PDF to image: \(pdfImage.size)")
                    Task {
                        await self.saveReceiptImage(pdfImage)
                    }
                } else {
                    print("❌ Could not convert PDF - convertPDFToImage returned nil")
                    self.updateStatus(error: "Could not convert PDF to image")
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 9, userInfo: nil))
                        }
                    }
                }
            } else {
                print("❌ Unsupported file type: \(pathExtension)")
                self.updateStatus(error: "Unsupported file type: .\(pathExtension)")
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 10, userInfo: nil))
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: error)
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 11, userInfo: nil))
                    }
                }
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 12, userInfo: nil))
                    }
                }
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
    
    // MARK: - Save Receipt Image
    private func saveReceiptImage(_ image: UIImage) async {
        print("💾 saveReceiptImage started")
        
        do {
            // Show image preview with animation
            print("📸 Showing image preview...")
            await showImagePreview(image)
            print("📸 Image preview shown")
            
            // Add a delay to ensure UI is visible before processing
            print("⏳ Waiting before save...")
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Validate image
            guard image.size.width > 0 && image.size.height > 0 else {
                throw ReceiptError.invalidImage
            }
            
            print("💾 Saving receipt to file...")
            let savedPath = try saveReceipt(image: image)
            
            // Notify main app
            notifyMainApp(imagePath: savedPath)
            
            print("✅ Receipt saved, showing success animation...")
            
            // Success! Show success state with animation and WAIT for it
            await showSuccess(message: "Receipt saved successfully!")
            
            print("✅ Success animation complete, waiting 0.9 seconds...")
            
            // Keep success fully visible - 0.9 seconds for quick but readable feedback
            try? await Task.sleep(nanoseconds: 900_000_000) // 0.9 seconds
            
            print("✅ Starting dismissal animation...")
            
            // Animate dismissal and wait for it
            await animateDismissal()
            
            print("✅ Dismissal complete, completing request...")
            
            // NOW complete the request after everything is done
            await MainActor.run {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
            
            print("✅ Extension completed successfully")
            
        } catch let error as ReceiptError {
            print("❌ ReceiptError: \(error.localizedDescription)")
            updateStatus(error: error.errorDescription ?? "Unknown error")
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await animateDismissal()
            await MainActor.run {
                self.extensionContext?.cancelRequest(withError: error)
            }
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            updateStatus(error: "Failed to save: \(error.localizedDescription)")
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await animateDismissal()
            await MainActor.run {
                self.extensionContext?.cancelRequest(withError: error)
            }
        }
    }
    
    // MARK: - Show Image Preview
    @MainActor
    private func showImagePreview(_ image: UIImage) async {
        imagePreview.image = image
        
        imagePreview.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Wait for the animation to complete
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) {
                self.imagePreview.alpha = 1
                self.imagePreview.transform = .identity
            } completion: { _ in
                continuation.resume()
            }
        }
        
        // Small delay after showing preview
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - Animate Dismissal
    @MainActor
    private func animateDismissal() async {
        print("👋 Starting dismissal animation")
        
        // Smooth fade out animation
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UIView.animate(withDuration: 0.4) {
                self.containerView.alpha = 0
                self.view.backgroundColor = UIColor.black.withAlphaComponent(0)
            } completion: { finished in
                print("👋 Dismissal animation finished: \(finished)")
                continuation.resume()
            }
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
    
    // MARK: - Show Success
    @MainActor
    private func showSuccess(message: String) async {
        print("🎉 showSuccess called")
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Update text
        titleLabel.text = "Success!"
        statusLabel.text = ""
        statusLabel.textColor = .systemGreen
        
        // Hide spinner
        activityIndicator.stopAnimating()
        
        // Small delay before animating checkmark
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        print("🎉 Starting checkmark animation")
        
        // Animate checkmark in with a dramatic bounce
        checkmarkView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        
        // Snappier animation - 0.6 seconds
        return await withCheckedContinuation { continuation in
            UIView.animate(
                withDuration: 0.6,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 0.8,
                options: [.curveEaseOut, .allowUserInteraction]
            ) {
                self.checkmarkView.alpha = 1
                self.checkmarkView.transform = .identity
            } completion: { finished in
                print("🎉 Checkmark animation finished: \(finished)")
                continuation.resume()
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

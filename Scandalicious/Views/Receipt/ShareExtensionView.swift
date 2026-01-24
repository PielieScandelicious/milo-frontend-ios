//
//  ShareExtensionView.swift
//  dobby-ios Share Extension
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Extension Context Environment Key
private struct ExtensionContextKey: EnvironmentKey {
    static let defaultValue: NSExtensionContext? = nil
}

extension EnvironmentValues {
    var extensionContext: NSExtensionContext? {
        get { self[ExtensionContextKey.self] }
        set { self[ExtensionContextKey.self] = newValue }
    }
}

// MARK: - Share Extension View
struct ShareExtensionView: View {
    @Environment(\.extensionContext) private var extensionContext
    
    let sharedItems: [NSExtensionItem]
    
    @State private var isProcessing = false
    @State private var uploadProgress: Double = 0.0
    @State private var currentFileName: String = ""
    @State private var uploadedCount = 0
    @State private var totalCount = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isComplete = false
    @State private var lastUploadResponse: ReceiptUploadResponse?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isComplete, let response = lastUploadResponse {
                        successView(response: response)
                    } else if isProcessing {
                        processingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        readyView
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Upload Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isComplete ? "Done" : "Cancel") {
                        cancelExtension()
                    }
                    .disabled(isProcessing && !isComplete)
                }
            }
        }
        .task {
            await processSharedItems()
        }
    }
    
    // MARK: - Subviews
    
    private var readyView: some View {
        Text("Preparing to upload...")
            .font(.headline)
            .foregroundStyle(.secondary)
    }
    
    private var processingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Uploading Receipts")
                .font(.headline)
            
            if totalCount > 1 {
                Text("\(uploadedCount) of \(totalCount) uploaded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if !currentFileName.isEmpty {
                Text(currentFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            ProgressView(value: uploadProgress)
                .tint(.blue)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receipt Processing Failed!")
                .font(.headline)

            Button("Dismiss") {
                cancelExtension()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func successView(response: ReceiptUploadResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)

                Text("Receipt Uploaded!")
                    .font(.headline)
            }

            if let storeName = response.storeName {
                HStack {
                    Image(systemName: "storefront.fill")
                        .foregroundColor(.blue)
                    Text(storeName)
                        .font(.subheadline)
                }
            }

            if let total = response.totalAmount {
                HStack {
                    Image(systemName: "eurosign.circle.fill")
                        .foregroundColor(.green)
                    Text(String(format: "€%.2f", total))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.secondary)
                Text("\(response.itemsCount) item\(response.itemsCount == 1 ? "" : "s")")
                    .font(.subheadline)
            }

            // Health Score Section
            if let healthScore = response.calculatedAverageHealthScore {
                Divider()

                HStack(spacing: 12) {
                    HealthScoreBadge(score: Int(healthScore.rounded()), size: .medium, style: .subtle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Health Score")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(healthScore.healthScoreLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(healthScore.healthScoreColor)
                    }
                }
            }
        }
    }
    
    // MARK: - Processing Logic
    
    private func processSharedItems() async {
        await MainActor.run {
            isProcessing = true
        }
        
        var itemsToUpload: [(Data, String, String)] = []
        
        // Extract all items first
        for item in sharedItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // Handle images
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    do {
                        let data = try await loadImageData(from: attachment)
                        let filename = generateFilename(extension: "jpg")
                        itemsToUpload.append((data, filename, "image/jpeg"))
                    } catch {
                        print("❌ Failed to load image: \(error.localizedDescription)")
                    }
                }
                // Handle PDFs
                else if attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    do {
                        let data = try await loadFileData(from: attachment, typeIdentifier: UTType.pdf.identifier)
                        let filename = generateFilename(extension: "pdf")
                        itemsToUpload.append((data, filename, "application/pdf"))
                    } catch {
                        print("❌ Failed to load PDF: \(error.localizedDescription)")
                    }
                }
                // Handle other files
                else if attachment.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                    do {
                        let data = try await loadFileData(from: attachment, typeIdentifier: UTType.item.identifier)
                        let filename = generateFilename(extension: "file")
                        itemsToUpload.append((data, filename, "application/octet-stream"))
                    } catch {
                        print("❌ Failed to load file: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Update total count
        await MainActor.run {
            totalCount = itemsToUpload.count
        }
        
        // Upload each item
        for (index, (data, filename, contentType)) in itemsToUpload.enumerated() {
            await MainActor.run {
                currentFileName = filename
                uploadProgress = Double(index) / Double(itemsToUpload.count)
            }
            
            do {
                let response = try await uploadData(data, filename: filename, contentType: contentType)
                print("✅ Uploaded: \(response.receiptId)")

                await MainActor.run {
                    uploadedCount += 1
                    lastUploadResponse = response
                }
            } catch {
                print("❌ Upload failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
                return
            }
        }
        
        // All uploads complete
        await MainActor.run {
            uploadProgress = 1.0
            isProcessing = false
            isComplete = true
        }
    }
    
    // MARK: - Data Loading
    
    private func loadImageData(from attachment: NSItemProvider) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Handle URL
                if let url = item as? URL {
                    do {
                        let data = try Data(contentsOf: url)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                // Handle UIImage
                if let image = item as? UIImage {
                    if let data = image.jpegData(compressionQuality: 1.0) {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: ReceiptUploadError.serverError("Failed to convert image to JPEG"))
                    }
                    return
                }
                
                // Handle Data
                if let data = item as? Data {
                    continuation.resume(returning: data)
                    return
                }
                
                continuation.resume(throwing: ReceiptUploadError.invalidResponse)
            }
        }
    }
    
    private func loadFileData(from attachment: NSItemProvider, typeIdentifier: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (item, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let url = item as? URL {
                    do {
                        let data = try Data(contentsOf: url)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                if let data = item as? Data {
                    continuation.resume(returning: data)
                    return
                }
                
                continuation.resume(throwing: ReceiptUploadError.invalidResponse)
            }
        }
    }
    
    // MARK: - Upload
    
    private func uploadData(_ data: Data, filename: String, contentType: String) async throws -> ReceiptUploadResponse {
        guard let url = URL(string: "\(AppConfiguration.backendBaseURL)/api/v1/receipts/upload") else {
            throw ReceiptUploadError.serverError("Invalid upload URL")
        }
        
        // Get auth token
        let idToken = try await getAuthToken()
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60 // 60 second timeout
        
        // Build request body
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform upload
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptUploadError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ReceiptUploadError.serverError("Server returned status code: \(httpResponse.statusCode)")
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(ReceiptUploadResponse.self, from: responseData)
        
        // Check if the receipt processing failed
        if uploadResponse.status == .failed {
            throw ReceiptUploadError.serverError("Receipt processing failed")
        }
        
        return uploadResponse
    }
    
    // MARK: - Get Auth Token
    
    private func getAuthToken() async throws -> String {
        // In Share Extension: Read from shared keychain/user defaults
        if let sharedDefaults = UserDefaults(suiteName: "group.com.deepmaind.scandalicious"),
           let token = sharedDefaults.string(forKey: "firebase_auth_token") {
            return token
        }
        
        // If not found, throw error
        throw ReceiptUploadError.noAuthToken
    }
    
    // MARK: - Helpers
    
    private func generateFilename(extension ext: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "receipt_\(timestamp).\(ext)"
    }
    
    private func completeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancelExtension() {
        if isComplete {
            // If complete, use completeRequest instead of cancel
            completeExtension()
        } else {
            extensionContext?.cancelRequest(withError: NSError(domain: "com.dobby.share", code: 0, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]))
        }
    }
}

// MARK: - Preview
#Preview {
    ShareExtensionView(sharedItems: [])
}
// MARK: - Data Extension for Multipart Form Data

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}


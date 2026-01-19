//
//  ShareExtensionView.swift
//  Dobby Share Extension
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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if isProcessing {
                        processingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        readyView
                    }
                }
                .padding()
            }
            .navigationTitle("Upload Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelExtension()
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .task {
            await processSharedItems()
        }
    }
    
    // MARK: - Subviews
    
    private var readyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.viewfinder.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Preparing to upload...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            // Upload icon with animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: uploadProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: uploadProgress)
                
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            
            VStack(spacing: 8) {
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
            }
            
            ProgressView(value: uploadProgress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Upload Failed")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Dismiss") {
                cancelExtension()
            }
            .buttonStyle(.borderedProminent)
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
                print("✅ Uploaded: \(response.s3_key)")
                
                await MainActor.run {
                    uploadedCount += 1
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
        }
        
        // Brief delay to show completion
        try? await Task.sleep(for: .milliseconds(500))
        
        // Close extension
        completeExtension()
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
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: ReceiptUploadError.imageConversionFailed)
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
        guard let url = URL(string: "https://3edaeenmik.eu-west-1.awsapprunner.com/upload") else {
            throw ReceiptUploadError.invalidURL
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
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
            throw ReceiptUploadError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(ReceiptUploadResponse.self, from: responseData)
        
        guard uploadResponse.isSuccess else {
            throw ReceiptUploadError.uploadFailed("Server returned non-success status")
        }
        
        return uploadResponse
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
        extensionContext?.cancelRequest(withError: NSError(domain: "com.dobby.share", code: 0, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]))
    }
}

// MARK: - Preview
#Preview {
    ShareExtensionView(sharedItems: [])
}

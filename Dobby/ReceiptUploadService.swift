//
//  ReceiptUploadService.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import Foundation
import UIKit

/// Response from the receipt upload API
struct ReceiptUploadResponse: Codable {
    let status: String
    let s3_key: String
    
    var isSuccess: Bool {
        status.lowercased() == "success"
    }
}

/// Errors that can occur during receipt upload
enum ReceiptUploadError: LocalizedError {
    case invalidURL
    case imageConversionFailed
    case pdfReadFailed
    case invalidResponse
    case uploadFailed(String)
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid upload URL"
        case .imageConversionFailed:
            return "Failed to convert image to JPEG format"
        case .pdfReadFailed:
            return "Failed to read PDF file"
        case .invalidResponse:
            return "Invalid response from server"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .serverError(let statusCode):
            return "Server error (status code: \(statusCode))"
        }
    }
}

/// Service for uploading receipts to the API
actor ReceiptUploadService {
    static let shared = ReceiptUploadService()
    
    private let uploadURL = "https://3edaeenmik.eu-west-1.awsapprunner.com/upload"
    
    private init() {}
    
    /// Upload a receipt image to the server
    /// - Parameters:
    ///   - image: The receipt image to upload
    ///   - filename: Optional custom filename (defaults to timestamp-based name)
    /// - Returns: The upload response containing the S3 key
    func uploadReceipt(image: UIImage, filename: String? = nil) async throws -> ReceiptUploadResponse {
        // Validate URL
        guard let url = URL(string: uploadURL) else {
            throw ReceiptUploadError.invalidURL
        }
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw ReceiptUploadError.imageConversionFailed
        }
        
        // Generate filename if not provided
        let finalFilename = filename ?? generateFilename()
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(finalFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform upload
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptUploadError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ReceiptUploadError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(ReceiptUploadResponse.self, from: data)
        
        guard uploadResponse.isSuccess else {
            throw ReceiptUploadError.uploadFailed("Server returned non-success status")
        }
        
        return uploadResponse
    }
    
    /// Upload a receipt from a file URL
    /// - Parameters:
    ///   - fileURL: The URL of the file to upload
    ///   - filename: Optional custom filename (defaults to the file's name)
    /// - Returns: The upload response containing the S3 key
    func uploadReceipt(from fileURL: URL, filename: String? = nil) async throws -> ReceiptUploadResponse {
        // Validate URL
        guard let url = URL(string: uploadURL) else {
            throw ReceiptUploadError.invalidURL
        }
        
        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        
        // Determine filename
        let finalFilename = filename ?? fileURL.lastPathComponent
        
        // Determine content type based on file extension
        let contentType: String
        switch fileURL.pathExtension.lowercased() {
        case "jpg", "jpeg":
            contentType = "image/jpeg"
        case "png":
            contentType = "image/png"
        case "pdf":
            contentType = "application/pdf"
        default:
            contentType = "application/octet-stream"
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(finalFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform upload
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptUploadError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ReceiptUploadError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(ReceiptUploadResponse.self, from: data)
        
        guard uploadResponse.isSuccess else {
            throw ReceiptUploadError.uploadFailed("Server returned non-success status")
        }
        
        return uploadResponse
    }
    
    /// Generate a timestamp-based filename for receipts
    private func generateFilename(extension: String = "jpg") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "receipt_\(timestamp).\(`extension`)"
    }
    
    /// Upload a PDF receipt directly without conversion
    /// - Parameters:
    ///   - pdfURL: The URL of the PDF file
    ///   - filename: Optional custom filename (defaults to timestamp-based name)
    /// - Returns: The upload response containing the S3 key
    func uploadPDFReceipt(from pdfURL: URL, filename: String? = nil) async throws -> ReceiptUploadResponse {
        // Validate URL
        guard let url = URL(string: uploadURL) else {
            throw ReceiptUploadError.invalidURL
        }
        
        // Read PDF data
        guard let pdfData = try? Data(contentsOf: pdfURL) else {
            throw ReceiptUploadError.pdfReadFailed
        }
        
        // Generate filename if not provided
        let finalFilename = filename ?? generateFilename(extension: "pdf")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var body = Data()
        
        // Add PDF file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(finalFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform upload
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptUploadError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ReceiptUploadError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(ReceiptUploadResponse.self, from: data)
        
        guard uploadResponse.isSuccess else {
            throw ReceiptUploadError.uploadFailed("Server returned non-success status")
        }
        
        return uploadResponse
    }
}

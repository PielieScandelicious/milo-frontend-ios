//
//  SharedReceiptManager.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import Foundation
import UIKit

/// Actor that manages local receipt storage and retrieval
/// Used for communication between Share Extension and main app
actor SharedReceiptManager {
    static let shared = SharedReceiptManager()
    
    private let fileManager = FileManager.default
    private let appGroupIdentifier = "group.com.dobby.app"
    
    private init() {}
    
    // MARK: - Directory Management
    
    /// Get the receipts directory in the App Group container
    func getReceiptsDirectory() -> URL? {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Failed to get App Group container")
            return nil
        }
        
        let receiptsURL = containerURL.appendingPathComponent("receipts", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: receiptsURL.path) {
            try? fileManager.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
        }
        
        return receiptsURL
    }
    
    // MARK: - Save Receipts
    
    /// Save a receipt image to local storage
    /// - Parameters:
    ///   - image: The receipt image to save
    ///   - storeName: Optional store name for organization
    /// - Returns: The URL of the saved image, or nil if saving failed
    func saveReceipt(image: UIImage, storeName: String? = nil) async -> URL? {
        guard let receiptsDirectory = getReceiptsDirectory() else {
            return nil
        }
        
        // Create store subdirectory if needed
        var targetDirectory = receiptsDirectory
        if let storeName = storeName?.lowercased() {
            targetDirectory = receiptsDirectory.appendingPathComponent(storeName, isDirectory: true)
            if !fileManager.fileExists(atPath: targetDirectory.path) {
                try? fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            }
        }
        
        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "receipt_\(timestamp).jpg"
        
        let fileURL = targetDirectory.appendingPathComponent(filename)
        
        // Convert image to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG")
            return nil
        }
        
        // Save to disk
        do {
            try imageData.write(to: fileURL)
            print("✅ Saved receipt to: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to save receipt: \(error)")
            return nil
        }
    }
    
    // MARK: - List Receipts
    
    /// List all saved receipt files
    /// - Returns: Array of URLs to saved receipt files
    func listSavedReceipts() async -> [URL] {
        guard let receiptsDirectory = getReceiptsDirectory() else {
            return []
        }
        
        var receipts: [URL] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: receiptsDirectory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            
            for itemURL in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // It's a store directory, list files inside
                        let storeReceipts = try fileManager.contentsOfDirectory(at: itemURL, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
                        receipts.append(contentsOf: storeReceipts.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" })
                    } else {
                        // It's a file directly in receipts folder
                        if itemURL.pathExtension.lowercased() == "jpg" || itemURL.pathExtension.lowercased() == "jpeg" {
                            receipts.append(itemURL)
                        }
                    }
                }
            }
            
            // Sort by creation date, newest first
            receipts.sort { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
        } catch {
            print("❌ Failed to list receipts: \(error)")
        }
        
        return receipts
    }
    
    // MARK: - Get Receipt Image
    
    /// Load a receipt image from disk
    /// - Parameter path: The file path of the receipt
    /// - Returns: The loaded UIImage, or nil if loading failed
    func getReceiptImage(at path: String) async -> UIImage? {
        guard fileManager.fileExists(atPath: path) else {
            print("❌ Receipt file not found at: \(path)")
            return nil
        }
        
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("❌ Failed to read image data from: \(path)")
            return nil
        }
        
        guard let image = UIImage(data: imageData) else {
            print("❌ Failed to create UIImage from data")
            return nil
        }
        
        return image
    }
    
    // MARK: - Delete Receipt
    
    /// Delete a receipt file
    /// - Parameter url: The URL of the receipt to delete
    /// - Returns: True if deletion was successful
    func deleteReceipt(at url: URL) async -> Bool {
        do {
            try fileManager.removeItem(at: url)
            print("✅ Deleted receipt: \(url.lastPathComponent)")
            return true
        } catch {
            print("❌ Failed to delete receipt: \(error)")
            return false
        }
    }
    
    // MARK: - Pending Receipts Queue (for future use with processing)
    
    private let pendingReceiptsKey = "pendingReceipts"
    
    /// Get list of pending receipts that need processing
    func getPendingReceipts() async -> [URL] {
        guard let receiptsDirectory = getReceiptsDirectory() else {
            return []
        }
        
        let pendingFile = receiptsDirectory.appendingPathComponent("pending.json")
        
        guard fileManager.fileExists(atPath: pendingFile.path),
              let data = try? Data(contentsOf: pendingFile),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        
        return paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }
    }
    
    /// Add a receipt to the pending queue
    func addToPendingQueue(receiptURL: URL) async {
        guard let receiptsDirectory = getReceiptsDirectory() else {
            return
        }
        
        let pendingFile = receiptsDirectory.appendingPathComponent("pending.json")
        
        // Read existing pending receipts
        var pending = await getPendingReceipts().map { $0.path }
        
        // Add new receipt if not already in queue
        if !pending.contains(receiptURL.path) {
            pending.append(receiptURL.path)
        }
        
        // Save updated queue
        if let data = try? JSONEncoder().encode(pending) {
            try? data.write(to: pendingFile)
        }
    }
    
    /// Clear all pending receipts from the queue
    func clearPendingReceipts() async {
        guard let receiptsDirectory = getReceiptsDirectory() else {
            return
        }
        
        let pendingFile = receiptsDirectory.appendingPathComponent("pending.json")
        try? fileManager.removeItem(at: pendingFile)
    }
}

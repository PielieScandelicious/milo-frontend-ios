//
//  SharedReceiptManager.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import Foundation
import UIKit

/// Manages receipts shared from the Share Extension
actor SharedReceiptManager {
    static let shared = SharedReceiptManager()
    
    private let appGroupIdentifier = "group.com.dobby.app"
    private let pendingReceiptsKey = "pendingReceipts"
    
    private init() {}
    
    // MARK: - Get Pending Receipts
    /// Retrieves all pending receipts from the App Group
    func getPendingReceipts() -> [SharedReceipt] {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let receiptsData = sharedDefaults.array(forKey: pendingReceiptsKey) as? [[String: Any]] else {
            return []
        }
        
        return receiptsData.compactMap { dict in
            guard let imagePath = dict["imagePath"] as? String,
                  let timestamp = dict["timestamp"] as? TimeInterval else {
                return nil
            }
            
            return SharedReceipt(
                imagePath: imagePath,
                date: Date(timeIntervalSince1970: timestamp)
            )
        }
    }
    
    // MARK: - Clear Pending Receipts
    /// Clears all pending receipts from the App Group
    func clearPendingReceipts() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        
        sharedDefaults.removeObject(forKey: pendingReceiptsKey)
        sharedDefaults.synchronize()
    }
    
    // MARK: - Mark Receipts as Viewed
    /// Clears the pending receipts list after user has viewed them
    func markReceiptsAsViewed() {
        clearPendingReceipts()
    }
    
    // MARK: - Get Receipts Directory
    /// Returns the URL for the receipts directory in the App Group
    func getReceiptsDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        
        return containerURL.appendingPathComponent("receipts")
    }
    
    // MARK: - List All Saved Receipts
    /// Lists all saved receipt images
    func listSavedReceipts() -> [URL] {
        guard let receiptsDir = getReceiptsDirectory() else {
            return []
        }
        
        do {
            let receipts = try FileManager.default.contentsOfDirectory(
                at: receiptsDir,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { url1, url2 in
                // Sort by creation date (newest first)
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            return receipts
        } catch {
            print("Error listing receipts: \(error)")
            return []
        }
    }
    
    // MARK: - Get Receipt Image
    /// Loads a receipt image from the given path
    func getReceiptImage(at path: String) -> UIImage? {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return UIImage(data: data)
    }
}

// MARK: - Shared Receipt Model
struct SharedReceipt: Identifiable {
    let id = UUID()
    let imagePath: String
    let date: Date
}


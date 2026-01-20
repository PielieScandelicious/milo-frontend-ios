//
//  SharedReceiptManager.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import Foundation
import UIKit

/// DEPRECATED: This manager is no longer used. All receipts are uploaded directly to the backend.
/// Kept for reference only - all functions now return empty/nil values.
actor SharedReceiptManager {
    static let shared = SharedReceiptManager()
    
    private init() {}
    
    // MARK: - Deprecated Functions (No-ops)
    
    /// DEPRECATED: Receipts are now uploaded directly to backend
    func saveReceipt(image: UIImage, storeName: String? = nil) async -> URL? {
        print("⚠️ SharedReceiptManager.saveReceipt is deprecated - use ReceiptUploadService instead")
        return nil
    }
    
    /// DEPRECATED: Receipts are now uploaded directly to backend
    func listSavedReceipts() async -> [URL] {
        print("⚠️ SharedReceiptManager.listSavedReceipts is deprecated - fetch from backend instead")
        return []
    }
    
    /// DEPRECATED: Receipts are now uploaded directly to backend
    func getReceiptImage(at path: String) async -> UIImage? {
        print("⚠️ SharedReceiptManager.getReceiptImage is deprecated - fetch from backend instead")
        return nil
    }
    
    /// DEPRECATED: Receipts are now uploaded directly to backend
    func deleteReceipt(at url: URL) async -> Bool {
        print("⚠️ SharedReceiptManager.deleteReceipt is deprecated - delete via backend API instead")
        return false
    }
    
    /// DEPRECATED: Receipts are now uploaded directly to backend
    func getPendingReceipts() async -> [URL] {
        print("⚠️ SharedReceiptManager.getPendingReceipts is deprecated")
        return []
    }
    
    /// DEPRECATED: Receipts are now uploaded directly to backend
    func addToPendingQueue(receiptURL: URL) async {
        print("⚠️ SharedReceiptManager.addToPendingQueue is deprecated")
    }
    
    /// DEPRECATED: Receipts are now uploaded directly to backend
    func clearPendingReceipts() async {
        print("⚠️ SharedReceiptManager.clearPendingReceipts is deprecated")
    }
}

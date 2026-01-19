//
//  SharedReceiptMonitor.swift
//  Dobby
//
//  Monitors the shared container for receipts imported via Share Extension
//

import Foundation
import SwiftUI

@MainActor
class SharedReceiptMonitor: ObservableObject {
    @Published var pendingReceipts: [PendingReceipt] = []
    
    private let containerIdentifier = "group.com.yourname.dobby"
    private var monitorTimer: Timer?
    
    init() {
        checkForSharedReceipts()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Check every 2 seconds for new receipts
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForSharedReceipts()
            }
        }
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    func checkForSharedReceipts() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: containerIdentifier
        ) else {
            return
        }
        
        let receiptsFolder = containerURL.appendingPathComponent("SharedReceipts")
        
        guard FileManager.default.fileExists(atPath: receiptsFolder.path) else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: receiptsFolder,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in files where fileURL.pathExtension == "json" {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let receiptData = try decoder.decode(ReceiptShareData.self, from: data)
                
                // Create pending receipt
                let pending = PendingReceipt(
                    id: UUID(),
                    fileURL: fileURL,
                    imageData: receiptData.imageData,
                    text: receiptData.text,
                    storeName: receiptData.storeName,
                    importDate: receiptData.date
                )
                
                // Add if not already in list
                if !pendingReceipts.contains(where: { $0.fileURL == fileURL }) {
                    pendingReceipts.append(pending)
                }
            }
        } catch {
            print("Error checking shared receipts: \(error)")
        }
    }
    
    func removePendingReceipt(_ receipt: PendingReceipt) {
        // Remove from list
        pendingReceipts.removeAll { $0.id == receipt.id }
        
        // Delete file
        do {
            try FileManager.default.removeItem(at: receipt.fileURL)
        } catch {
            print("Error deleting shared receipt file: \(error)")
        }
    }
    
    func clearAllPendingReceipts() {
        for receipt in pendingReceipts {
            do {
                try FileManager.default.removeItem(at: receipt.fileURL)
            } catch {
                print("Error deleting shared receipt file: \(error)")
            }
        }
        pendingReceipts.removeAll()
    }
}

struct PendingReceipt: Identifiable {
    let id: UUID
    let fileURL: URL
    let imageData: Data?
    let text: String?
    let storeName: String
    let importDate: Date
    
    var displayName: String {
        "\(storeName) - \(importDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

// Reuse the same struct from ShareExtensionView
struct ReceiptShareData: Codable {
    let imageData: Data?
    let text: String?
    let storeName: String
    let date: Date
}

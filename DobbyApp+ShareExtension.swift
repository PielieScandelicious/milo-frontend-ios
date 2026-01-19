//
//  DobbyApp+ShareExtension.swift
//  Dobby
//
//  Example integration for Share Extension
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

// MARK: - Example: Main App Entry Point
// Add this to your existing DobbyApp file
// No automatic processing needed - receipts are just stored

/*
@main
struct DobbyApp: App {
    @StateObject private var transactionManager = TransactionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transactionManager)
        }
    }
}
*/

// MARK: - Example: Add Receipts to Your Navigation

/*
struct SettingsView: View {
    var body: some View {
        List {
            Section("Receipts") {
                NavigationLink {
                    SavedReceiptsView()
                } label: {
                    Label("Saved Receipts", systemImage: "doc.text.image")
                }
                
                NavigationLink {
                    ReceiptScanView()
                } label: {
                    Label("Scan New Receipt", systemImage: "camera.viewfinder")
                }
            }
            
            Section("Data") {
                Button {
                    Task {
                        await checkReceiptsStatus()
                    }
                } label: {
                    Label("Check Pending Receipts", systemImage: "tray.full")
                }
            }
        }
    }
    
    private func checkReceiptsStatus() async {
        let pending = await SharedReceiptManager.shared.getPendingReceipts()
        let saved = await SharedReceiptManager.shared.listSavedReceipts()
        
        print("📥 Pending receipts: \(pending.count)")
        print("💾 Saved receipts: \(saved.count)")
    }
}
*/

// MARK: - Example: Receipt List View - View All Saved Receipts

struct ReceiptListView: View {
    @State private var pendingReceipts: [SharedReceipt] = []
    @State private var savedReceipts: [URL] = []
    
    var body: some View {
        List {
            Section("Recently Added") {
                if pendingReceipts.isEmpty {
                    Text("No new receipts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pendingReceipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(imagePath: receipt.imagePath, date: receipt.date)
                        } label: {
                            VStack(alignment: .leading) {
                                Text("Receipt")
                                    .font(.headline)
                                Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Section("All Receipts") {
                if savedReceipts.isEmpty {
                    Text("No saved receipts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(savedReceipts, id: \.self) { url in
                        NavigationLink {
                            ReceiptDetailView(url: url)
                        } label: {
                            Text(url.lastPathComponent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Receipts")
        .task {
            await loadReceipts()
        }
        .refreshable {
            await loadReceipts()
        }
        .toolbar {
            Button("Clear New Badge") {
                Task {
                    await SharedReceiptManager.shared.markReceiptsAsViewed()
                    await loadReceipts()
                }
            }
        }
    }
    
    private func loadReceipts() async {
        let pending = await SharedReceiptManager.shared.getPendingReceipts()
        let saved = await SharedReceiptManager.shared.listSavedReceipts()
        
        await MainActor.run {
            pendingReceipts = pending
            savedReceipts = saved
        }
    }
}

struct ReceiptDetailView: View {
    let imagePath: String?
    let url: URL?
    let date: Date?
    
    init(imagePath: String, date: Date) {
        self.imagePath = imagePath
        self.url = nil
        self.date = date
    }
    
    init(url: URL) {
        self.url = url
        self.imagePath = nil
        self.date = nil
    }
    
    var body: some View {
        ScrollView {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                ContentUnavailableView(
                    "Cannot Load Receipt",
                    systemImage: "photo",
                    description: Text("The receipt image could not be loaded")
                )
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadImage() -> UIImage? {
        if let imagePath = imagePath {
            return UIImage(contentsOfFile: imagePath)
        } else if let url = url {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}


// MARK: - Example: Receipt Statistics View

struct ReceiptStatsView: View {
    @State private var stats: ReceiptStats?
    
    var body: some View {
        List {
            if let stats = stats {
                Section("Statistics") {
                    LabeledContent("Total Receipts", value: "\(stats.totalReceipts)")
                    LabeledContent("Pending", value: "\(stats.pendingCount)")
                    LabeledContent("Processed", value: "\(stats.processedCount)")
                }
                
                Section("By Store") {
                    ForEach(stats.receiptsByStore.sorted(by: { $0.key < $1.key }), id: \.key) { store, count in
                        LabeledContent(store, value: "\(count)")
                    }
                }
                
                if let dir = stats.storageLocation {
                    Section("Storage") {
                        VStack(alignment: .leading) {
                            Text("Location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dir)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Receipt Stats")
        .task {
            await loadStats()
        }
        .refreshable {
            await loadStats()
        }
    }
    
    private func loadStats() async {
        let pending = await SharedReceiptManager.shared.getPendingReceipts()
        let saved = await SharedReceiptManager.shared.listSavedReceipts()
        let dir = await SharedReceiptManager.shared.getReceiptsDirectory()
        
        let totalSaved = saved.count
        // Since we don't have store information in the saved receipts yet,
        // we'll create a simple count dictionary
        let receiptsByStore: [String: Int] = totalSaved > 0 ? ["All Receipts": totalSaved] : [:]
        
        await MainActor.run {
            stats = ReceiptStats(
                totalReceipts: totalSaved + pending.count,
                pendingCount: pending.count,
                processedCount: totalSaved,
                receiptsByStore: receiptsByStore,
                storageLocation: dir?.path
            )
        }
    }
}

struct ReceiptStats {
    let totalReceipts: Int
    let pendingCount: Int
    let processedCount: Int
    let receiptsByStore: [String: Int]
    let storageLocation: String?
}

// MARK: - Example: Receipt Count Badge

struct ReceiptBadge: View {
    @State private var pendingCount = 0
    
    var body: some View {
        NavigationLink {
            ReceiptListView()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "doc.text.image")
                    .font(.title2)
                
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .offset(x: 8, y: -8)
                }
            }
        }
        .task {
            await updateBadge()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await updateBadge()
            }
        }
    }
    
    private func updateBadge() async {
        let receipts = await SharedReceiptManager.shared.getPendingReceipts()
        await MainActor.run {
            pendingCount = receipts.count
        }
    }
}

// MARK: - Example: Preview

#Preview("Receipt List") {
    NavigationStack {
        ReceiptListView()
    }
}

#Preview("Stats View") {
    NavigationStack {
        ReceiptStatsView()
    }
}

#Preview("Badge") {
    ReceiptBadge()
        .padding()
}

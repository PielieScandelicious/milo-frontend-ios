//
//  SavedReceiptsView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

struct SavedReceiptsView: View {
    @State private var receipts: [URL] = []
    @State private var selectedReceipt: URL?
    @State private var selectedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color(white: 0.05)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            } else if receipts.isEmpty {
                emptyState
            } else {
                receiptsList
            }
        }
        .sheet(item: Binding(
            get: { selectedReceipt.map { IdentifiableReceiptURL(url: $0) } },
            set: { selectedReceipt = $0?.url }
        )) { item in
            ReceiptImageView(image: selectedImage)
        }
        .navigationTitle("Saved Receipts")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadReceipts()
        }
        .refreshable {
            await loadReceipts()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Receipts Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Share receipt images to Dobby from Photos or other apps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Receipts List
    private var receiptsList: some View {
        List {
            ForEach(receipts, id: \.self) { receiptURL in
                ReceiptRow(url: receiptURL)
                    .onTapGesture {
                        openReceipt(url: receiptURL)
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Load Receipts
    private func loadReceipts() async {
        isLoading = true
        let loadedReceipts = await SharedReceiptManager.shared.listSavedReceipts()
        await MainActor.run {
            receipts = loadedReceipts
            isLoading = false
        }
    }
    
    // MARK: - Open Receipt
    private func openReceipt(url: URL) {
        Task {
            let image = await SharedReceiptManager.shared.getReceiptImage(at: url.path)
            await MainActor.run {
                selectedImage = image
                selectedReceipt = url
            }
        }
    }
}

// MARK: - Receipt Row
struct ReceiptRow: View {
    let url: URL
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                        }
                }
            }
            .frame(width: 60, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(1)
                
                if let date = creationDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private var creationDate: Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }
    
    private func loadThumbnail() async {
        let image = await SharedReceiptManager.shared.getReceiptImage(at: url.path)
        await MainActor.run {
            thumbnail = image
        }
    }
}

// MARK: - Receipt Image View
struct ReceiptImageView: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = scale
                                    // Limit zoom
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    } else if scale > 5.0 {
                                        withAnimation {
                                            scale = 5.0
                                            lastScale = 5.0
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Failed to load image")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if image != nil {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: Image(uiImage: image!), preview: SharePreview("Receipt"))
                    }
                }
            }
        }
    }
}

// MARK: - Helper Types
private struct IdentifiableReceiptURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SavedReceiptsView()
    }
}

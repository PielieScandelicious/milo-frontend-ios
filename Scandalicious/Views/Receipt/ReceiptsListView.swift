//
//  ReceiptsListView.swift
//  Scandalicious
//
//  Created by Claude on 24/01/2026.
//

import SwiftUI

struct ReceiptsListView: View {
    let period: String
    let storeName: String?

    @StateObject private var viewModel = ReceiptsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReceipt: APIReceipt?
    @State private var showingReceiptDetail = false
    @State private var isDeleting = false
    @State private var isDeletingItem = false
    @State private var deleteError: String?
    @State private var expandedReceiptId: String?
    @State private var receiptToSplit: APIReceipt?

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            if viewModel.state.isLoading && viewModel.receipts.isEmpty {
                loadingView
            } else if viewModel.receipts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.receipts) { receipt in
                                ExpandableReceiptCard(
                                    receipt: receipt,
                                    isExpanded: expandedReceiptId == receipt.receiptId,
                                    onTap: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            if expandedReceiptId == receipt.receiptId {
                                                expandedReceiptId = nil
                                            } else {
                                                expandedReceiptId = receipt.receiptId
                                            }
                                        }
                                    },
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            deleteReceipt(receipt)
                                        }
                                    },
                                    onDeleteItem: { receiptId, itemId in
                                        deleteReceiptItem(receiptId: receiptId, itemId: itemId)
                                    },
                                    onSplit: {
                                        receiptToSplit = receipt
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }

                            // Load more indicator
                            if viewModel.hasMorePages {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding()
                                    .onAppear {
                                        Task {
                                            await viewModel.loadNextPage(period: period, storeName: storeName)
                                        }
                                    }
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.receipts.count)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }
                .refreshable {
                    await viewModel.refresh(period: period, storeName: storeName)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Receipts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(period)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .navigationDestination(isPresented: $showingReceiptDetail) {
            if let receipt = selectedReceipt {
                ReceiptTransactionsView(receipt: receipt)
            }
        }
        .sheet(item: $receiptToSplit) { receipt in
            SplitExpenseView(receipt: receipt.toReceiptUploadResponse())
        }
        .task {
            await viewModel.loadReceipts(period: period, storeName: storeName)
        }
        .alert("Error", isPresented: .constant(viewModel.state.error != nil)) {
            Button("OK") { }
        } message: {
            if let error = viewModel.state.error {
                Text(error)
            }
        }
        .alert("Delete Failed", isPresented: .constant(deleteError != nil)) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("Deleting...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.15))
                    )
                }
            }
        }
    }

    // MARK: - Delete Receipt

    private func deleteReceipt(_ receipt: APIReceipt) {
        isDeleting = true

        Task {
            do {
                try await viewModel.deleteReceipt(receipt, period: period, storeName: storeName)

                // Haptic feedback for successful deletion
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                deleteError = error.localizedDescription

                // Haptic feedback for failure
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }

            isDeleting = false
        }
    }

    // MARK: - Delete Receipt Item

    private func deleteReceiptItem(receiptId: String, itemId: String) {
        Task {
            do {
                try await viewModel.deleteReceiptItem(receiptId: receiptId, itemId: itemId)

                // Haptic feedback already handled in the component
            } catch {
                deleteError = error.localizedDescription

                // Haptic feedback for failure
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }

    // MARK: - Components

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text("Loading receipts...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 60)

            Text("No Receipts")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("No receipts found for this period")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
}

// Note: ReceiptRowWithDelete has been replaced with the shared ExpandableReceiptCard component
// located in Scandalicious/Views/Components/ExpandableReceiptCard.swift

// MARK: - Preview

#Preview {
    NavigationStack {
        ReceiptsListView(period: "January 2026", storeName: "COLRUYT")
    }
    .preferredColorScheme(.dark)
}

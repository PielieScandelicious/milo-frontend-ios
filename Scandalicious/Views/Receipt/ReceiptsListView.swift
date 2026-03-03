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
    var initialReceipts: [APIReceipt]? = nil

    @StateObject private var viewModel = ReceiptsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReceipt: APIReceipt?
    @State private var showingReceiptDetail = false
    @State private var expandedReceiptId: String?

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            if viewModel.state.isLoading && viewModel.receipts.isEmpty {
                // Skeleton loading instead of spinner
                ScrollView {
                    SkeletonReceiptList(count: 5)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }
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
                    Text(L("receipts"))
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
        .task {
            // Use initial/cached receipts for instant display
            if let initial = initialReceipts, !initial.isEmpty, viewModel.receipts.isEmpty {
                viewModel.receipts = initial
                viewModel.state = .success(initial)
                // Background refresh for fresh data
                Task {
                    await viewModel.loadReceipts(period: period, storeName: storeName, reset: true)
                }
            } else {
                await viewModel.loadReceipts(period: period, storeName: storeName)
            }
        }
        .alert(L("error"), isPresented: .constant(viewModel.state.error != nil)) {
            Button(L("ok")) { }
        } message: {
            if let error = viewModel.state.error {
                Text(error)
            }
        }
    }

    // MARK: - Components

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 60)

            Text(L("no_receipts"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text(L("no_receipts_found"))
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

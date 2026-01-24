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
                                Button {
                                    selectedReceipt = receipt
                                    showingReceiptDetail = true
                                } label: {
                                    receiptRow(receipt)
                                }
                                .buttonStyle(ReceiptRowButtonStyle())
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

    private func receiptRow(_ receipt: APIReceipt) -> some View {
        HStack(spacing: 16) {
            // Receipt icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
            }

            // Receipt details
            VStack(alignment: .leading, spacing: 4) {
                // Date as main title
                Text(receipt.formattedDate)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Text(receipt.displayStoreName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("•")
                        .foregroundColor(.white.opacity(0.3))

                    Text("\(receipt.itemsCount) item\(receipt.itemsCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Health score if available
                if let healthScore = receipt.averageHealthScore {
                    HStack(spacing: 4) {
                        HealthScoreBadge(score: Int(healthScore.rounded()), size: .small, style: .subtle)

                        Text(healthScore.healthScoreLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(healthScore.healthScoreColor)
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "€%.2f", receipt.displayTotalAmount))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Button Style

struct ReceiptRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReceiptsListView(period: "January 2026", storeName: "COLRUYT")
    }
    .preferredColorScheme(.dark)
}

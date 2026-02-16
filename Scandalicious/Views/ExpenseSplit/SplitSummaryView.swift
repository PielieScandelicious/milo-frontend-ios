//
//  SplitSummaryView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 02/02/2026.
//

import SwiftUI

struct SplitSummaryView: View {
    let receipt: ReceiptUploadResponse
    let results: [SplitResult]
    let shareText: String
    let onSaveAndDismiss: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    summaryHeader

                    // Per-person breakdown
                    VStack(spacing: 12) {
                        ForEach(results.sorted(by: { $0.amount > $1.amount })) { result in
                            PersonBreakdownCard(result: result)
                        }
                    }
                    .padding(.horizontal)

                    // Share button
                    shareButton
                        .padding(.horizontal)

                    // Done button - saves and returns to receipts
                    doneButton
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L("split_summary"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: shareText)
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            // Store name
            HStack {
                Image(systemName: "storefront.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text(receipt.storeName ?? "Receipt")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Total
            if let total = receipt.totalAmount {
                VStack(spacing: 4) {
                    Text(L("total"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(total, format: .currency(code: "EUR"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
            }

            // Participants count
            Text("\(L("split_between")) \(results.count) \(results.count == 1 ? L("person") : L("people"))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text(L("share_split"))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            Task {
                isSaving = true
                await onSaveAndDismiss()
                isSaving = false
            }
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.blue)
                } else {
                    Image(systemName: "checkmark")
                    Text(L("done"))
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isSaving)
    }
}

// MARK: - Person Breakdown Card

struct PersonBreakdownCard: View {
    let result: SplitResult

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(result.participant.swiftUIColor)
                            .frame(width: 50, height: 50)

                        Text(result.participant.initials)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // Name and item count
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.participant.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("\(result.itemCount) \(result.itemCount == 1 ? "item" : "items")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Amount
                    Text(result.amount, format: .currency(code: "EUR"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Expanded items list
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.items.indices, id: \.self) { index in
                        let item = result.items[index]
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            if item.price != item.share {
                                Text("\(item.price, format: .currency(code: "EUR")) / \(numberOfSplitters(for: item))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Text(item.share, format: .currency(code: "EUR"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func numberOfSplitters(for item: (name: String, price: Double, share: Double)) -> Int {
        if item.share > 0 {
            return Int(round(item.price / item.share))
        }
        return 1
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    SplitSummaryView(
        receipt: ReceiptUploadResponse(
            receiptId: "123",
            status: .success,
            storeName: "The Local Bar",
            receiptDate: "2026-02-02",
            totalAmount: 47.50,
            itemsCount: 4,
            transactions: [],
            warnings: [],
            averageHealthScore: 2.5
        ),
        results: [
            SplitResult(
                participant: SplitParticipant(name: "Gilles M", color: "#FF6B6B", displayOrder: 0),
                amount: 15.83,
                itemCount: 3,
                items: [
                    (name: "Pizza Margherita", price: 12.00, share: 4.00),
                    (name: "Beer", price: 15.00, share: 7.50),
                    (name: "Nachos", price: 8.50, share: 4.33),
                ]
            ),
            SplitResult(
                participant: SplitParticipant(name: "John Doe", color: "#4ECDC4", displayOrder: 1),
                amount: 15.83,
                itemCount: 3,
                items: [
                    (name: "Pizza Margherita", price: 12.00, share: 4.00),
                    (name: "Beer", price: 15.00, share: 7.50),
                    (name: "Nachos", price: 8.50, share: 4.33),
                ]
            ),
            SplitResult(
                participant: SplitParticipant(name: "Sarah", color: "#FFE66D", displayOrder: 2),
                amount: 15.84,
                itemCount: 3,
                items: [
                    (name: "Pizza Margherita", price: 12.00, share: 4.00),
                    (name: "Beer", price: 15.00, share: 7.50),
                    (name: "Nachos", price: 8.50, share: 4.34),
                ]
            ),
        ],
        shareText: """
        Split for The Local Bar
        Total: 47.50 EUR

        Gilles M: 15.83 EUR
        John Doe: 15.83 EUR
        Sarah: 15.84 EUR

        Sent from Scandalicious
        """,
        onSaveAndDismiss: {}
    )
}

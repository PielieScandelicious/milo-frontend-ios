//
//  RecentReceiptsCard.swift
//  Scandalicious
//
//  Collapsible, scrollable list of past successfully uploaded receipts.
//  Fetches more pages as the user scrolls (infinite scroll).
//

import SwiftUI

struct RecentReceiptsCard: View {
    @ObservedObject var viewModel: ReceiptsViewModel
    @Binding var isExpanded: Bool
    var onTapReceipt: ((APIReceipt) -> Void)? = nil

    /// Maximum visible height when expanded (rows × approximate row height)
    private let expandedMaxHeight: CGFloat = 5 * 60

    var body: some View {
        VStack(spacing: 0) {
            // Tappable header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                headerContent
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 16)

                if viewModel.receipts.isEmpty {
                    emptyState
                } else {
                    receiptList
                }
            }
        }
        .padding(.bottom, isExpanded ? 8 : 0)
        .background(cardBackground)
        .overlay(cardBorder)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Header

    private var headerContent: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            Text("Recent Receipts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Receipt List

    private var receiptList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.receipts) { receipt in
                    RecentReceiptRow(receipt: receipt)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTapReceipt?(receipt)
                        }
                        .onAppear {
                            // Infinite scroll: fetch next page when near the end
                            if receipt.id == viewModel.receipts.last?.id && viewModel.hasMorePages {
                                Task {
                                    await viewModel.loadNextPage(period: "All")
                                }
                            }
                        }

                    if receipt.id != viewModel.receipts.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 52)
                            .padding(.trailing, 16)
                    }
                }

                // Loading indicator at the bottom
                if viewModel.hasMorePages {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.3)))
                            .scaleEffect(0.7)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxHeight: expandedMaxHeight)
        .clipped()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.2))
            Text("No receipts yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Card Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(white: 0.08))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
}

// MARK: - Recent Receipt Row

private struct RecentReceiptRow: View {
    let receipt: APIReceipt

    var body: some View {
        HStack(spacing: 12) {
            // Store icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)

                Image(systemName: "storefront.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Store name + date
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.storeName?.localizedCapitalized ?? "Unknown Store")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let dateStr = receipt.receiptDate {
                        Text(Self.formatDate(dateStr))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    if receipt.itemsCount > 0 {
                        Text("\u{2022} \(receipt.itemsCount) items")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }

            Spacer()

            // Amount
            if let amount = receipt.totalAmount {
                Text(String(format: "\u{20AC}%.2f", amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Format "2026-02-16" → "16 Feb"
    private static func formatDate(_ isoDate: String) -> String {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = isoFormatter.date(from: isoDate) else { return isoDate }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM"
        return displayFormatter.string(from: date)
    }
}

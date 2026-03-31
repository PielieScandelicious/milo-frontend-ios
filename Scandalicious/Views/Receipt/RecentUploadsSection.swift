//
//  RecentUploadsSection.swift
//  Scandalicious
//
//  Recent receipt uploads displayed on the Home tab.
//  Apple-style grouped card with staggered row reveals.
//

import SwiftUI

struct RecentUploadsSection: View {
    let receipts: [APIReceipt]
    let isLoading: Bool
    let onRefresh: () -> Void

    @State private var expandedReceiptId: String?
    @State private var showAllReceipts = false
    @State private var visibleRowIDs: Set<String> = []

    private var visibleReceipts: [APIReceipt] {
        if showAllReceipts {
            return receipts
        }
        return Array(receipts.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading && receipts.isEmpty {
                loadingState
            } else if receipts.isEmpty {
                emptyState
            } else {
                receiptsList
            }
        }
        .padding(.bottom, 12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(cardBorder)
        .onChange(of: receipts.map(\.receiptId)) { _, newIDs in
            staggerReveal(ids: newIDs)
        }
        .onAppear {
            staggerReveal(ids: visibleReceipts.map(\.receiptId))
        }
    }

    // MARK: - Staggered Reveal

    private func staggerReveal(ids: [String]) {
        for (index, id) in ids.enumerated() {
            guard !visibleRowIDs.contains(id) else { continue }
            let delay = Double(index) * 0.05
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82).delay(delay)) {
                visibleRowIDs.insert(id)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            Text("Recent Receipts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            if isLoading && !receipts.isEmpty {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.4))
                    .transition(.opacity)
            }

            Text("\(receipts.count)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .contentTransition(.numericText())
                .animation(.snappy, value: receipts.count)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Receipts List

    private var receiptsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleReceipts.enumerated()), id: \.element.receiptId) { index, receipt in
                let isVisible = visibleRowIDs.contains(receipt.receiptId)

                VStack(spacing: 0) {
                    RecentUploadRow(
                        receipt: receipt,
                        isExpanded: expandedReceiptId == receipt.receiptId,
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                if expandedReceiptId == receipt.receiptId {
                                    expandedReceiptId = nil
                                } else {
                                    expandedReceiptId = receipt.receiptId
                                }
                            }
                        }
                    )

                    if index < visibleReceipts.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 56)
                            .padding(.trailing, 16)
                    }
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 8)
            }

            // Show all / show less
            if receipts.count > 5 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        showAllReceipts.toggle()
                        if !showAllReceipts {
                            expandedReceiptId = nil
                        }
                    }
                    if showAllReceipts {
                        staggerReveal(ids: receipts.map(\.receiptId))
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllReceipts ? "Show Less" : "Show All")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: showAllReceipts ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: CGFloat.random(in: 80...120), height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 60, height: 10)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 55, height: 14)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index < 2 {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 0.5)
                        .padding(.leading, 56)
                        .padding(.trailing, 16)
                }
            }
        }
        .shimmer()
        .transition(.opacity.animation(.easeIn(duration: 0.2)))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white.opacity(0.12))

            Text("No receipts yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))

            Text("Scan a receipt to get started")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.18))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .transition(.opacity.animation(.easeIn(duration: 0.3)))
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
                    colors: [.white.opacity(0), .white.opacity(0.15), .white.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
}

// MARK: - Receipt Row

private struct RecentUploadRow: View {
    let receipt: APIReceipt
    let isExpanded: Bool
    let onTap: () -> Void

    private var resolvedStore: GroceryStore? {
        guard let name = receipt.storeName else { return nil }
        return GroceryStore.fromCanonical(name)
            ?? GroceryStore.allCases.first {
                $0.rawValue.caseInsensitiveCompare(name) == .orderedSame
            }
            ?? GroceryStore.allCases.first {
                name.localizedCaseInsensitiveContains($0.displayName)
            }
    }

    private var storeColor: Color {
        resolvedStore?.accentColor ?? Color(white: 0.45)
    }

    private var formattedDate: String {
        guard let date = receipt.dateParsed else {
            return receipt.receiptDate ?? ""
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }

    private var itemCountLabel: String {
        let count = receipt.transactions.reduce(0) { $0 + $1.quantity }
        return "\(count) item\(count == 1 ? "" : "s")"
    }

    private var sortedTransactions: [APIReceiptItem] {
        receipt.transactions.sorted { $0.itemPrice > $1.itemPrice }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tappable row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    storeIcon

                    VStack(alignment: .leading, spacing: 3) {
                        Text(receipt.displayStoreName.localizedCapitalized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text(formattedDate)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))

                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 3, height: 3)

                            Text(itemCountLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }

                    Spacer(minLength: 4)

                    Text(String(format: "\u{20AC}%.2f", receipt.displayTotalAmount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.18))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(ReceiptRowButtonStyle())

            // Expanded items
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            VStack(spacing: 2) {
                ForEach(Array(sortedTransactions.prefix(8).enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 6) {
                        Text(item.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)

                        if item.quantity > 1 {
                            Text("\u{00D7}\(item.quantity)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.25))
                        }

                        Spacer()

                        Text(String(format: "\u{20AC}%.2f", item.itemPrice))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 20)
                }

                if sortedTransactions.count > 8 {
                    Text("+\(sortedTransactions.count - 8) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Store Icon

    @ViewBuilder
    private var storeIcon: some View {
        if let store = resolvedStore {
            ZStack {
                Circle()
                    .fill(storeColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(store.logoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
            }
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 40, height: 40)

                Image(systemName: "storefront.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

// MARK: - Button Style

private struct ReceiptRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

//
//  SplitExpenseView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 02/02/2026.
//

import SwiftUI

struct SplitExpenseView: View {
    let receipt: ReceiptUploadResponse

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseSplitViewModel

    @State private var showAddFriend = false
    @State private var newFriendName = ""
    @State private var showSummary = false
    @State private var showShareSheet = false

    init(receipt: ReceiptUploadResponse) {
        self.receipt = receipt
        self._viewModel = StateObject(wrappedValue: ExpenseSplitViewModel(receipt: receipt))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with receipt info
                receiptHeader

                // Friends chips bar
                friendsSection

                Divider()

                // Items list with split controls
                itemsList

                // Bottom summary bar
                if !viewModel.participants.isEmpty {
                    summaryBar
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Split Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Done") {
                            Task {
                                await viewModel.saveSplit()
                                if viewModel.error == nil {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(viewModel.participants.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(
                    friendName: $newFriendName,
                    recentFriends: viewModel.recentFriends,
                    existingParticipants: viewModel.participants,
                    onAddNew: { name in
                        viewModel.addParticipant(name: name)
                    },
                    onAddRecent: { friend in
                        viewModel.addParticipantFromRecent(friend)
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSummary) {
                SplitSummaryView(
                    receipt: receipt,
                    results: viewModel.calculateSplits(),
                    shareText: viewModel.generateShareText(),
                    onSaveAndDismiss: {
                        await viewModel.saveSplit()
                        if viewModel.error == nil {
                            showSummary = false
                            dismiss()
                        }
                    }
                )
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "An error occurred")
            }
            .task {
                await viewModel.loadRecentFriends()
                await viewModel.loadExistingSplit()
            }
        }
    }

    // MARK: - Receipt Header

    private var receiptHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.storeName ?? "Receipt")
                    .font(.headline)

                if let date = receipt.parsedDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let total = receipt.totalAmount {
                Text(total, format: .currency(code: "EUR"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Friends")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.participants.count > 1 {
                    Button("Split All Equally") {
                        withAnimation {
                            viewModel.assignAllToEveryone()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if viewModel.participants.isEmpty {
                // Empty state
                Button {
                    showAddFriend = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                        Text("Add friends to split with")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            } else {
                FriendChipsRow(
                    participants: viewModel.participants,
                    onAddTap: {
                        showAddFriend = true
                    },
                    onParticipantTap: nil,
                    onParticipantLongPress: { participant in
                        viewModel.removeParticipant(participant)
                    }
                )
            }
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(receipt.transactions) { transaction in
                    let stableTransactionId = viewModel.getStableTransactionId(for: transaction)
                    SplitItemRow(
                        transaction: transaction,
                        participants: viewModel.participants,
                        selectedParticipantIds: viewModel.getAssignedParticipantIds(
                            for: stableTransactionId
                        ),
                        onToggle: { participant in
                            viewModel.toggleAssignment(
                                transactionId: stableTransactionId,
                                participantId: participant.id.uuidString
                            )
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        VStack(spacing: 12) {
            // Per-person totals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.calculateSplits()) { result in
                        HStack(spacing: 8) {
                            MiniFriendAvatar(
                                participant: result.participant,
                                isSelected: true,
                                size: 28
                            )

                            VStack(alignment: .leading, spacing: 0) {
                                Text(result.participant.name.split(separator: " ").first ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(result.amount, format: .currency(code: "EUR"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Share button
            Button {
                showSummary = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("View Summary & Share")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Split Item Row

struct SplitItemRow: View {
    let transaction: ReceiptTransaction
    let participants: [SplitParticipant]
    let selectedParticipantIds: Set<String>
    var onToggle: ((SplitParticipant) -> Void)?

    private var categoryColor: Color {
        switch transaction.category.color {
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "gray": return .gray
        case "pink": return .pink
        case "green": return .green
        case "yellow": return .yellow
        case "brown": return .brown
        case "mint": return .mint
        case "cyan": return .cyan
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item info row
            HStack(alignment: .top, spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: transaction.category.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(categoryColor)
                }

                // Item details
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.itemName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    if transaction.quantity > 1 {
                        Text("Qty: \(transaction.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Price
                Text(transaction.itemPrice, format: .currency(code: "EUR"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Participant toggles
            if !participants.isEmpty {
                HStack(spacing: 4) {
                    Text("Split:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ItemParticipantAvatars(
                        participants: participants,
                        selectedIds: selectedParticipantIds,
                        onToggle: onToggle
                    )

                    Spacer()

                    // Show per-person amount
                    if !selectedParticipantIds.isEmpty {
                        let perPerson = transaction.itemPrice / Double(selectedParticipantIds.count)
                        Text("\(perPerson, format: .currency(code: "EUR"))/person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    SplitExpenseView(
        receipt: ReceiptUploadResponse(
            receiptId: "123",
            status: .success,
            storeName: "The Local Bar",
            receiptDate: "2026-02-02",
            totalAmount: 47.50,
            itemsCount: 4,
            transactions: [
                ReceiptTransaction(
                    itemId: "t1",
                    itemName: "Pizza Margherita",
                    itemPrice: 12.00,
                    quantity: 1,
                    unitPrice: 12.00,
                    category: .readyMeals,
                    healthScore: 3
                ),
                ReceiptTransaction(
                    itemId: "t2",
                    itemName: "Beer",
                    itemPrice: 15.00,
                    quantity: 3,
                    unitPrice: 5.00,
                    category: .alcohol,
                    healthScore: 1
                ),
                ReceiptTransaction(
                    itemId: "t3",
                    itemName: "Nachos with Guacamole",
                    itemPrice: 8.50,
                    quantity: 1,
                    unitPrice: 8.50,
                    category: .snacksAndSweets,
                    healthScore: 2
                ),
                ReceiptTransaction(
                    itemId: "t4",
                    itemName: "Sparkling Water",
                    itemPrice: 4.00,
                    quantity: 2,
                    unitPrice: 2.00,
                    category: .drinksWater,
                    healthScore: 5
                ),
            ],
            warnings: [],
            averageHealthScore: 2.5
        )
    )
}

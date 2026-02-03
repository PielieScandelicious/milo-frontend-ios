//
//  SplitTransactionView.swift
//  Scandalicious
//
//  Created by Claude Code on 03/02/2026.
//

import SwiftUI

// MARK: - Split Transaction View

struct SplitTransactionView: View {
    let transaction: APITransaction
    let storeName: String

    @Environment(\.dismiss) private var dismiss
    @State private var participants: [SplitParticipant] = []
    @State private var showAddFriend = false
    @State private var newFriendName = ""
    @State private var recentFriends: [RecentFriend] = []
    @State private var isLoading = false

    init(transaction: APITransaction, storeName: String) {
        self.transaction = transaction
        self.storeName = storeName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Transaction header
                transactionHeader

                // Friends section
                friendsSection

                Divider()

                // Split summary
                if participants.count > 1 {
                    splitSummary
                } else {
                    emptyState
                }

                Spacer()

                // Share button
                if participants.count > 1 {
                    shareButton
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Split Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(
                    friendName: $newFriendName,
                    recentFriends: recentFriends,
                    existingParticipants: participants,
                    onAddNew: { name in
                        addParticipant(name: name)
                    },
                    onAddRecent: { friend in
                        addParticipantFromRecent(friend)
                    }
                )
                .presentationDetents([.medium])
            }
            .task {
                setupDefaultMeParticipant()
                await loadRecentFriends()
            }
        }
    }

    // MARK: - Transaction Header

    private var transactionHeader: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: categoryIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.itemName)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(storeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = transaction.dateParsed {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.totalPrice, format: .currency(code: "EUR"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)

                if transaction.quantity > 1 {
                    Text("Qty: \(transaction.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Split with")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                if participants.count > 1 {
                    Text("\(participants.count) people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if participants.isEmpty {
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
                    participants: participants,
                    onAddTap: {
                        showAddFriend = true
                    },
                    onParticipantTap: nil,
                    onParticipantLongPress: { participant in
                        removeParticipant(participant)
                    }
                )
            }
        }
    }

    // MARK: - Split Summary

    private var splitSummary: some View {
        VStack(spacing: 16) {
            Text("Each person pays")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 20)

            let perPerson = transaction.totalPrice / Double(participants.count)

            Text(perPerson, format: .currency(code: "EUR"))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Participant list with amounts
            VStack(spacing: 12) {
                ForEach(participants) { participant in
                    HStack(spacing: 12) {
                        MiniFriendAvatar(
                            participant: participant,
                            isSelected: true,
                            size: 36
                        )

                        Text(participant.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text(perPerson, format: .currency(code: "EUR"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.top, 40)

            Text("Add friends to split")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Tap the + button above to add people to split this expense with.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        ShareLink(item: generateShareText()) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Split")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }

    // MARK: - Helper Properties

    private var categoryColor: Color {
        switch transaction.category.lowercased() {
        case "meat_fish": return .red
        case "alcohol": return .purple
        case "drinks": return .blue
        case "fresh_produce": return .green
        case "dairy_eggs": return .yellow
        case "bakery": return .orange
        case "frozen_foods": return .cyan
        case "pantry_staples": return .brown
        case "snacks_sweets": return .pink
        case "prepared_meals", "ready_meals": return .orange
        case "condiments_sauces": return .mint
        case "household": return .gray
        case "personal_care": return .purple
        case "baby_products": return .pink
        case "pet_supplies": return .brown
        default: return .gray
        }
    }

    private var categoryIcon: String {
        switch transaction.category.lowercased() {
        case "meat_fish": return "fish.fill"
        case "alcohol": return "wineglass.fill"
        case "drinks": return "cup.and.saucer.fill"
        case "fresh_produce": return "leaf.fill"
        case "dairy_eggs": return "carton.fill"
        case "bakery": return "birthday.cake.fill"
        case "frozen_foods": return "snowflake"
        case "pantry_staples": return "cabinet.fill"
        case "snacks_sweets": return "birthday.cake.fill"
        case "prepared_meals", "ready_meals": return "takeoutbag.and.cup.and.straw.fill"
        case "condiments_sauces": return "drop.fill"
        case "household": return "house.fill"
        case "personal_care": return "heart.fill"
        case "baby_products": return "figure.child"
        case "pet_supplies": return "pawprint.fill"
        default: return "bag.fill"
        }
    }

    // MARK: - Participant Management

    private func setupDefaultMeParticipant() {
        let meParticipant = SplitParticipant.createMe(displayOrder: 0)
        participants.append(meParticipant)
    }

    private func addParticipant(name: String) {
        let color = FriendColor.fromIndex(participants.count).rawValue
        let participant = SplitParticipant(
            name: name,
            color: color,
            displayOrder: participants.count
        )
        participants.append(participant)
    }

    private func addParticipantFromRecent(_ friend: RecentFriend) {
        let participant = SplitParticipant(
            name: friend.name,
            color: friend.color,
            displayOrder: participants.count
        )
        participants.append(participant)
    }

    private func removeParticipant(_ participant: SplitParticipant) {
        // Don't allow removing "Me"
        guard !participant.isMe else { return }
        participants.removeAll { $0.id == participant.id }

        // Reorder remaining participants
        for i in 0..<participants.count {
            participants[i].displayOrder = i
        }
    }

    private func loadRecentFriends() async {
        do {
            recentFriends = try await ExpenseSplitAPIService.shared.getRecentFriends()
        } catch {
            print("Failed to load recent friends: \(error)")
        }
    }

    private func generateShareText() -> String {
        var lines: [String] = []
        let perPerson = transaction.totalPrice / Double(participants.count)

        lines.append("Split for \(transaction.itemName)")
        lines.append("at \(storeName)")
        lines.append(String(format: "Total: %.2f EUR", transaction.totalPrice))
        lines.append("")
        lines.append("Each person pays:")

        for participant in participants.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            lines.append(String(format: "  %@: %.2f EUR", participant.name, perPerson))
        }

        lines.append("")
        lines.append("Sent from Scandalicious")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Preview

#Preview {
    SplitTransactionView(
        transaction: APITransaction(
            id: "123",
            storeName: "COLRUYT",
            itemName: "Pizza Margherita",
            itemPrice: 12.00,
            quantity: 1,
            category: "PREPARED_MEALS",
            date: "2026-02-03",
            healthScore: 3
        ),
        storeName: "COLRUYT"
    )
}

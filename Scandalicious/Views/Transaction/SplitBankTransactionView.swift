//
//  SplitBankTransactionView.swift
//  Scandalicious
//
//  Simple split view for bank-imported transactions.
//  Unlike scanned receipts, bank transactions have a single amount to split.
//

import SwiftUI

// MARK: - Split Mode

enum SplitMode: String, CaseIterable {
    case equal = "Equal"
    case custom = "Custom"
}

struct SplitBankTransactionView: View {
    let receipt: APIReceipt

    @Environment(\.dismiss) private var dismiss
    @State private var participants: [SplitParticipant] = []
    @State private var showAddFriend = false
    @State private var newFriendName = ""
    @State private var recentFriends: [RecentFriend] = []
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var showError = false
    @State private var existingSplitId: String?

    // Custom split state
    @State private var splitMode: SplitMode = .equal
    @State private var customAmounts: [UUID: Double] = [:]
    @State private var editingParticipantId: UUID?
    @FocusState private var focusedField: UUID?

    // MARK: - Computed Properties

    private var totalAmount: Double {
        receipt.displayTotalAmount
    }

    private var equalSplitAmount: Double {
        guard participants.count > 0 else { return 0 }
        return totalAmount / Double(participants.count)
    }

    private var customTotalSum: Double {
        participants.reduce(0) { sum, participant in
            sum + (customAmounts[participant.id] ?? 0)
        }
    }

    private var amountDifference: Double {
        totalAmount - customTotalSum
    }

    private var isCustomSplitValid: Bool {
        abs(amountDifference) < 0.01
    }

    private var canSave: Bool {
        participants.count > 1 && (splitMode == .equal || isCustomSplitValid)
    }

    private func amountForParticipant(_ participant: SplitParticipant) -> Double {
        if splitMode == .equal {
            return equalSplitAmount
        } else {
            return customAmounts[participant.id] ?? 0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
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

                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Loading...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
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
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "An error occurred")
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
                await loadExistingSplit()
                await loadRecentFriends()
            }
        }
    }

    // MARK: - Transaction Header

    private var transactionHeader: some View {
        HStack(spacing: 12) {
            // Bank icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.displayStoreName.localizedCapitalized)
                    .font(.headline)
                    .lineLimit(2)

                if let dateString = receipt.receiptDate {
                    Text(formattedDate(dateString))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formattedAmount(receipt.displayTotalAmount))
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
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
            // Split mode picker
            splitModePicker
                .padding(.top, 12)

            // Amount display
            if splitMode == .equal {
                Text("Each person pays")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(equalSplitAmount, format: .currency(code: "EUR"))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            } else {
                // Custom mode header
                VStack(spacing: 4) {
                    Text("Custom split")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(totalAmount, format: .currency(code: "EUR"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                }
            }

            // Participant list with amounts
            VStack(spacing: 0) {
                ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                    VStack(spacing: 0) {
                        participantRow(participant: participant)

                        if index < participants.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.horizontal)

            // Validation message for custom mode
            if splitMode == .custom {
                validationBanner
            }
        }
    }

    // MARK: - Split Mode Picker

    private var splitModePicker: some View {
        Picker("Split Mode", selection: $splitMode) {
            ForEach(SplitMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: splitMode) { _, newMode in
            if newMode == .custom {
                // Initialize custom amounts with equal split
                initializeCustomAmounts()
            }
        }
    }

    // MARK: - Participant Row

    private func participantRow(participant: SplitParticipant) -> some View {
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

            if splitMode == .equal {
                Text(equalSplitAmount, format: .currency(code: "EUR"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            } else {
                // Editable amount field
                editableAmountField(for: participant)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Editable Amount Field

    private func editableAmountField(for participant: SplitParticipant) -> some View {
        HStack(spacing: 4) {
            Text("€")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField(
                "0.00",
                value: Binding(
                    get: { customAmounts[participant.id] ?? 0 },
                    set: { customAmounts[participant.id] = $0 }
                ),
                format: .number.precision(.fractionLength(2))
            )
            .font(.subheadline)
            .fontWeight(.semibold)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
            .focused($focusedField, equals: participant.id)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Validation Banner

    private var validationBanner: some View {
        Group {
            if isCustomSplitValid {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Split adds up correctly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    if amountDifference > 0 {
                        Text("€\(String(format: "%.2f", amountDifference)) remaining to assign")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("€\(String(format: "%.2f", abs(amountDifference))) over the total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Quick-fix button to distribute remainder
                    if abs(amountDifference) > 0.001 {
                        Button {
                            distributeRemainder()
                        } label: {
                            Text("Fix")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
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
        VStack(spacing: 12) {
            // Dismiss keyboard button when editing
            if focusedField != nil {
                Button {
                    focusedField = nil
                } label: {
                    HStack {
                        Image(systemName: "keyboard.chevron.compact.down")
                        Text("Done Editing")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            ShareLink(item: generateShareText()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Split")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSave ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                .foregroundStyle(canSave ? .blue : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canSave)

            // Done button to save split
            Button {
                Task {
                    await saveSplit()
                }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(canSave ? Color.blue : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(isSaving || !canSave)
        }
        .padding()
    }

    // MARK: - Helper Functions

    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d, yyyy"
        return outputFormatter.string(from: date)
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "€"
        return formatter.string(from: NSNumber(value: amount)) ?? "€\(String(format: "%.2f", amount))"
    }

    // MARK: - Custom Split Helpers

    private func initializeCustomAmounts() {
        for participant in participants {
            if customAmounts[participant.id] == nil {
                customAmounts[participant.id] = equalSplitAmount
            }
        }
    }

    private func distributeRemainder() {
        guard !participants.isEmpty else { return }

        // Add the remaining amount to the first participant (typically "Me")
        let firstParticipant = participants.first!
        let currentAmount = customAmounts[firstParticipant.id] ?? 0
        customAmounts[firstParticipant.id] = currentAmount + amountDifference
    }

    private func resetToEqualSplit() {
        customAmounts.removeAll()
        for participant in participants {
            customAmounts[participant.id] = equalSplitAmount
        }
    }

    // MARK: - Participant Management

    private func setupDefaultMeParticipant() {
        // Only add "Me" if not already present
        guard participants.isEmpty else { return }
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

        // Recalculate custom amounts when in custom mode
        if splitMode == .custom {
            redistributeAmountsEqually()
        }
    }

    private func addParticipantFromRecent(_ friend: RecentFriend) {
        let participant = SplitParticipant(
            name: friend.name,
            color: friend.color,
            displayOrder: participants.count
        )
        participants.append(participant)

        // Recalculate custom amounts when in custom mode
        if splitMode == .custom {
            redistributeAmountsEqually()
        }
    }

    private func removeParticipant(_ participant: SplitParticipant) {
        // Don't allow removing "Me"
        guard !participant.isMe else { return }

        // Remove custom amount for this participant
        customAmounts.removeValue(forKey: participant.id)

        participants.removeAll { $0.id == participant.id }

        // Reorder remaining participants
        for i in 0..<participants.count {
            participants[i].displayOrder = i
        }

        // Recalculate custom amounts when in custom mode
        if splitMode == .custom && !participants.isEmpty {
            redistributeAmountsEqually()
        }
    }

    private func redistributeAmountsEqually() {
        let newEqualAmount = totalAmount / Double(participants.count)
        for participant in participants {
            customAmounts[participant.id] = newEqualAmount
        }
    }

    private func loadRecentFriends() async {
        do {
            recentFriends = try await ExpenseSplitAPIService.shared.getRecentFriends()
        } catch {
            // Failed to load recent friends
        }
    }

    private func loadExistingSplit() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let existingSplit = try await ExpenseSplitAPIService.shared.getSplitForReceipt(receiptId: receipt.receiptId) {
                // Populate from existing split
                self.existingSplitId = existingSplit.id
                self.participants = existingSplit.participants

                // Check if any participant has a custom amount (indicates custom split mode)
                let hasCustomAmounts = existingSplit.participants.contains { $0.customAmount != nil }
                if hasCustomAmounts {
                    // Restore custom split mode
                    self.splitMode = .custom
                    // Populate customAmounts dictionary from participants
                    for participant in existingSplit.participants {
                        if let amount = participant.customAmount {
                            self.customAmounts[participant.id] = amount
                        }
                    }
                }

                // Cache the loaded split
                SplitCacheManager.shared.cacheSplit(existingSplit)
            } else {
                // No existing split - set up default "Me" participant
                setupDefaultMeParticipant()
            }
        } catch {
            // Not an error - just means no split exists yet, set up default "Me"
            setupDefaultMeParticipant()
        }
    }

    private func generateShareText() -> String {
        var lines: [String] = []

        lines.append("Split for \(receipt.displayStoreName)")
        lines.append(String(format: "Total: %.2f EUR", totalAmount))
        lines.append("")

        if splitMode == .equal {
            lines.append("Each person pays:")
            for participant in participants.sorted(by: { $0.displayOrder < $1.displayOrder }) {
                lines.append(String(format: "  %@: %.2f EUR", participant.name, equalSplitAmount))
            }
        } else {
            lines.append("Split breakdown:")
            for participant in participants.sorted(by: { $0.displayOrder < $1.displayOrder }) {
                let amount = customAmounts[participant.id] ?? 0
                lines.append(String(format: "  %@: %.2f EUR", participant.name, amount))
            }
        }

        lines.append("")
        lines.append("Sent from Scandalicious")

        return lines.joined(separator: "\n")
    }

    // MARK: - Save Split

    private func saveSplit() async {
        // Only save if we have more than just "Me"
        guard participants.count > 1 else {
            dismiss()
            return
        }

        isSaving = true
        error = nil

        do {
            // Build participant requests with custom amounts if in custom mode
            let participantRequests = participants.map { p in
                ParticipantCreateRequest(
                    name: p.name,
                    color: p.color,
                    customAmount: splitMode == .custom ? customAmounts[p.id] : nil,
                    isMe: p.isMe
                )
            }

            // For bank transactions, we need the actual transaction ID from the transactions array
            // Bank imports create one receipt with one transaction entry
            guard let transactionId = receipt.transactions.first?.itemId else {
                // Fallback to receiptId if no transaction found (shouldn't happen for imported bank transactions)
                await MainActor.run {
                    self.error = "Transaction not found"
                    self.showError = true
                    self.isSaving = false
                }
                return
            }

            // Create mapping from participant UUID (lowercase) to index
            let allParticipantIndices = participants.enumerated().map { String($0.offset) }

            // Single assignment: all participants share the total
            let assignmentRequests = [
                AssignmentCreateRequest(
                    transactionId: transactionId,
                    participantIds: allParticipantIndices
                )
            ]

            let request = ExpenseSplitCreateRequest(
                receiptId: receipt.receiptId,
                participants: participantRequests,
                assignments: assignmentRequests
            )

            // Use update if we have an existing split, otherwise create new
            let savedSplit: ExpenseSplit
            if let existingId = existingSplitId {
                savedSplit = try await ExpenseSplitAPIService.shared.updateSplit(splitId: existingId, request: request)
            } else {
                savedSplit = try await ExpenseSplitAPIService.shared.saveSplit(request)
            }

            // Cache the split for display
            await MainActor.run {
                SplitCacheManager.shared.cacheSplit(savedSplit)

                // Post notification for UI updates
                NotificationCenter.default.post(
                    name: .expenseSplitSaved,
                    object: nil,
                    userInfo: ["split": savedSplit, "receiptId": receipt.receiptId]
                )
            }

            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.showError = true
                self.isSaving = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplitBankTransactionView(
        receipt: APIReceipt(
            receiptId: "1",
            storeName: "Colruyt Kessel-Lo",
            receiptDate: "2026-02-01",
            totalAmount: 45.67,
            itemsCount: 1,
            averageHealthScore: nil,
            source: .bankImport,
            transactions: []
        )
    )
}

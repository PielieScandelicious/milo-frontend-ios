//
//  ExpenseSplitViewModel.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 02/02/2026.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Split Result (computed locally)

struct SplitResult: Identifiable {
    let participant: SplitParticipant
    let amount: Double
    let itemCount: Int
    let items: [(name: String, price: Double, share: Double)]

    var id: UUID { participant.id }
}

// MARK: - ExpenseSplitViewModel

@MainActor
class ExpenseSplitViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var participants: [SplitParticipant] = []
    @Published var assignments: [String: Set<String>] = [:]  // transactionId -> Set of participant IDs
    @Published var recentFriends: [RecentFriend] = []
    @Published var isSaving = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var savedSplitId: String?

    // MARK: - Private Properties

    private let receipt: ReceiptUploadResponse

    /// Stable transaction ID mapping - maps transaction to a stable identifier
    /// This is needed because transaction.id is regenerated on each decode
    private var stableTransactionIds: [Int: String] = [:]

    // MARK: - Initialization

    init(receipt: ReceiptUploadResponse) {
        self.receipt = receipt
        buildStableTransactionIds()
        setupDefaultMeParticipant()
    }

    /// Set up the default "Me" participant and assign to all items
    private func setupDefaultMeParticipant() {
        let meParticipant = SplitParticipant.createMe(displayOrder: 0)
        participants.append(meParticipant)

        // Auto-assign "Me" to all items
        let meIdLower = meParticipant.id.uuidString.lowercased()
        for transaction in receipt.transactions {
            let transactionId = getStableTransactionId(for: transaction)
            assignments[transactionId] = Set([meIdLower])
        }
    }

    /// Build stable transaction IDs that persist across receipt re-decodes
    /// Uses itemId when available, otherwise creates a deterministic ID based on position
    private func buildStableTransactionIds() {
        for (index, transaction) in receipt.transactions.enumerated() {
            // Use itemId if available (backend's stable ID), otherwise use index-based ID
            let stableId = transaction.itemId ?? "local-item-\(index)"
            stableTransactionIds[index] = stableId
        }
    }

    /// Get stable transaction ID for a transaction at given index
    func getStableTransactionId(at index: Int) -> String? {
        return stableTransactionIds[index]
    }

    /// Get stable transaction ID for a transaction
    func getStableTransactionId(for transaction: ReceiptTransaction) -> String {
        // Find the transaction in the array and get its stable ID
        if let index = receipt.transactions.firstIndex(where: { $0.id == transaction.id }) {
            return stableTransactionIds[index] ?? transaction.itemId ?? transaction.id.uuidString
        }
        // Fallback to itemId or UUID (should rarely happen)
        return transaction.itemId ?? transaction.id.uuidString
    }

    // MARK: - Computed Properties

    /// Calculate split results for all participants
    func calculateSplits() -> [SplitResult] {
        var results: [SplitResult] = []

        for participant in participants {
            var totalAmount: Double = 0
            var itemCount = 0
            var items: [(name: String, price: Double, share: Double)] = []

            // Normalize participant ID to lowercase for comparison (backend returns lowercase UUIDs)
            let participantIdLower = participant.id.uuidString.lowercased()

            for transaction in receipt.transactions {
                let transactionId = getStableTransactionId(for: transaction)

                let assignedParticipants = assignments[transactionId] ?? Set()
                // Compare with lowercase normalization
                if assignedParticipants.contains(where: { $0.lowercased() == participantIdLower }) {
                    let numSplitters = assignedParticipants.count
                    let shareAmount = transaction.itemPrice / Double(numSplitters)

                    totalAmount += shareAmount
                    itemCount += 1
                    items.append((
                        name: transaction.itemName,
                        price: transaction.itemPrice,
                        share: shareAmount
                    ))
                }
            }

            results.append(SplitResult(
                participant: participant,
                amount: round(totalAmount * 100) / 100,
                itemCount: itemCount,
                items: items
            ))
        }

        return results
    }

    /// Get total assigned amount (should equal receipt total when everything is assigned)
    var totalAssigned: Double {
        calculateSplits().reduce(0) { $0 + $1.amount }
    }

    /// Check if all items are assigned to at least one person
    var allItemsAssigned: Bool {
        for transaction in receipt.transactions {
            let transactionId = getStableTransactionId(for: transaction)
            let assignedParticipants = assignments[transactionId] ?? Set()
            if assignedParticipants.isEmpty {
                return false
            }
        }
        return true
    }

    // MARK: - Participant Management

    func addParticipant(name: String) {
        let color = FriendColor.fromIndex(participants.count).rawValue
        let participant = SplitParticipant(
            name: name,
            color: color,
            displayOrder: participants.count
        )
        participants.append(participant)
        // New friends are NOT auto-assigned to any items
        // User must tap the greyed out avatar per item to assign
    }

    func addParticipantFromRecent(_ friend: RecentFriend) {
        let participant = SplitParticipant(
            name: friend.name,
            color: friend.color,
            displayOrder: participants.count
        )
        participants.append(participant)
        // New friends are NOT auto-assigned to any items
        // User must tap the greyed out avatar per item to assign
    }

    func removeParticipant(_ participant: SplitParticipant) {
        participants.removeAll { $0.id == participant.id }

        // Remove from all assignments (case-insensitive)
        let participantIdLower = participant.id.uuidString.lowercased()
        for key in assignments.keys {
            if let existingId = assignments[key]?.first(where: { $0.lowercased() == participantIdLower }) {
                assignments[key]?.remove(existingId)
            }
        }

        // Reorder remaining participants
        for i in 0..<participants.count {
            participants[i].displayOrder = i
        }
    }

    // MARK: - Assignment Management

    func toggleAssignment(transactionId: String, participantId: String) {
        if assignments[transactionId] == nil {
            assignments[transactionId] = Set()
        }

        // Normalize to lowercase for consistent comparison with backend UUIDs
        let normalizedId = participantId.lowercased()

        // Check if already assigned (case-insensitive)
        if let existingId = assignments[transactionId]!.first(where: { $0.lowercased() == normalizedId }) {
            assignments[transactionId]!.remove(existingId)
        } else {
            assignments[transactionId]!.insert(normalizedId)
        }
    }

    func assignAllToEveryone() {
        // Use lowercase IDs for consistency with backend
        let allParticipantIds = Set(participants.map { $0.id.uuidString.lowercased() })

        for transaction in receipt.transactions {
            let transactionId = getStableTransactionId(for: transaction)
            assignments[transactionId] = allParticipantIds
        }
    }

    func getAssignedParticipantIds(for transactionId: String) -> Set<String> {
        return assignments[transactionId] ?? Set()
    }

    // MARK: - API Integration

    func loadRecentFriends() async {
        do {
            recentFriends = try await ExpenseSplitAPIService.shared.getRecentFriends()
        } catch {
            // Non-critical, don't show error to user
        }
    }

    func loadExistingSplit() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let existingSplit = try await ExpenseSplitAPIService.shared.getSplitForReceipt(receiptId: receipt.receiptId) {
                // Populate from existing split
                self.savedSplitId = existingSplit.id
                self.participants = existingSplit.participants

                // Convert assignments - use the backend's transaction IDs
                self.assignments = [:]
                for assignment in existingSplit.assignments {
                    self.assignments[assignment.transactionId] = Set(assignment.participantIds)
                }

                // Cache the loaded split for ExpandableReceiptCard display
                SplitCacheManager.shared.cacheSplit(existingSplit)
            }
        } catch {
            // Not an error - just means no split exists yet
        }
    }

    func saveSplit() async {
        isSaving = true
        error = nil

        do {
            // Build request
            let participantRequests = participants.map { p in
                ParticipantCreateRequest(name: p.name, color: p.color, isMe: p.isMe)
            }

            // Create mapping from participant UUID (lowercase) to index (0-based)
            let uuidToIndex: [String: Int] = Dictionary(
                uniqueKeysWithValues: participants.enumerated().map { ($1.id.uuidString.lowercased(), $0) }
            )

            // Convert participant UUIDs to indices for backend
            let assignmentRequests = assignments.map { (transactionId, participantIds) in
                let indices = participantIds.compactMap { uuid -> Int? in
                    uuidToIndex[uuid.lowercased()]
                }.map { String($0) }

                return AssignmentCreateRequest(
                    transactionId: transactionId,
                    participantIds: indices  // Sends ["0", "1", "2"] indices instead of UUIDs
                )
            }

            let request = ExpenseSplitCreateRequest(
                receiptId: receipt.receiptId,
                participants: participantRequests,
                assignments: assignmentRequests
            )

            let savedSplit = try await ExpenseSplitAPIService.shared.saveSplit(request)
            self.savedSplitId = savedSplit.id

            // Update participants with server-assigned IDs
            self.participants = savedSplit.participants

            // Update assignments with server data
            self.assignments = [:]
            for assignment in savedSplit.assignments {
                self.assignments[assignment.transactionId] = Set(assignment.participantIds)
            }

            // Cache the split and post notification for UI updates
            SplitCacheManager.shared.cacheSplit(savedSplit)
            NotificationCenter.default.post(
                name: .expenseSplitSaved,
                object: nil,
                userInfo: ["split": savedSplit, "receiptId": receipt.receiptId]
            )

            // Also notify analytics to refresh (split changes "My Share" amounts)
            NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)

        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Share Text Generation

    func generateShareText() -> String {
        let results = calculateSplits()
        var lines: [String] = []

        lines.append("Split for \(receipt.storeName ?? "Receipt")")
        if let total = receipt.totalAmount {
            lines.append(String(format: "Total: %.2f EUR", total))
        }
        lines.append("")

        for result in results.sorted(by: { $0.amount > $1.amount }) {
            lines.append(String(format: "%@: %.2f EUR", result.participant.name, result.amount))
        }

        lines.append("")
        lines.append("Sent from Scandalicious")

        return lines.joined(separator: "\n")
    }
}

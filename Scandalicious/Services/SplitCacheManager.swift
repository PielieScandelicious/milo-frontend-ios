//
//  SplitCacheManager.swift
//  Scandalicious
//
//  Created by Claude on 02/02/2026.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Split Participant Info (lightweight for display)

struct SplitParticipantInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let color: String
    let isMe: Bool

    var swiftUIColor: Color {
        Color(hex: color) ?? .gray
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let last = parts[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

// MARK: - Cached Split Data

struct CachedSplitData: Equatable {
    let splitId: String
    let receiptId: String
    let participants: [SplitParticipantInfo]
    /// Maps transaction ID (lowercased) to array of participant IDs who share this item
    private let assignmentsLowercased: [String: [String]]
    /// Original assignments for Equatable conformance
    let assignments: [String: [String]]
    /// Maps participant ID (lowercased) to participant info for quick lookup
    private let participantMap: [String: SplitParticipantInfo]

    init(splitId: String, receiptId: String, participants: [SplitParticipantInfo], assignments: [String: [String]]) {
        self.splitId = splitId
        self.receiptId = receiptId
        self.participants = participants
        self.assignments = assignments

        // Build lowercased assignments map for case-insensitive lookup
        var lowercasedAssignments: [String: [String]] = [:]
        for (key, value) in assignments {
            lowercasedAssignments[key.lowercased()] = value
        }
        self.assignmentsLowercased = lowercasedAssignments

        // Build participant lookup map with lowercased keys
        var map: [String: SplitParticipantInfo] = [:]
        for p in participants {
            map[p.id.lowercased()] = p
        }
        self.participantMap = map
    }

    /// Get participants for a specific transaction (case-insensitive lookup)
    func participantsForTransaction(_ transactionId: String) -> [SplitParticipantInfo] {
        // Case-insensitive lookup for transaction ID
        guard let participantIds = assignmentsLowercased[transactionId.lowercased()] else {
            return []
        }

        var result: [SplitParticipantInfo] = []
        for pid in participantIds {
            let pidLower = pid.lowercased()
            // Case-insensitive ID match for participant lookup
            if let participant = participantMap[pidLower] {
                result.append(participant)
            }
        }

        return result
    }

    /// Check if a transaction has been split (case-insensitive lookup)
    func isTransactionSplit(_ transactionId: String) -> Bool {
        guard let participantIds = assignmentsLowercased[transactionId.lowercased()] else { return false }
        return !participantIds.isEmpty
    }

    static func == (lhs: CachedSplitData, rhs: CachedSplitData) -> Bool {
        lhs.splitId == rhs.splitId &&
        lhs.receiptId == rhs.receiptId &&
        lhs.participants == rhs.participants &&
        lhs.assignments == rhs.assignments
    }
}

// MARK: - Split Cache Manager

/// Manages cached split data for receipts to display friend indicators
@MainActor
class SplitCacheManager: ObservableObject {
    static let shared = SplitCacheManager()

    /// Cache of split data by receipt ID
    @Published private(set) var cache: [String: CachedSplitData] = [:]

    /// Loading state for receipts being fetched
    @Published private(set) var loadingReceipts: Set<String> = []

    private init() {
        // Listen for split saved notifications
        NotificationCenter.default.addObserver(
            forName: .expenseSplitSaved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let split = notification.userInfo?["split"] as? ExpenseSplit {
                    self?.cacheSplit(split)
                }
            }
        }
    }

    // MARK: - Public API

    /// Get cached split data for a receipt
    func getSplit(for receiptId: String) -> CachedSplitData? {
        return cache[receiptId]
    }

    /// Check if a receipt has a cached split
    func hasSplit(for receiptId: String) -> Bool {
        return cache[receiptId] != nil
    }

    /// Fetch and cache split data for a receipt from the API
    func fetchSplit(for receiptId: String) async {
        guard !loadingReceipts.contains(receiptId) else { return }

        loadingReceipts.insert(receiptId)
        defer { loadingReceipts.remove(receiptId) }

        do {
            if let split = try await ExpenseSplitAPIService.shared.getSplitForReceipt(receiptId: receiptId) {
                cacheSplit(split)
            }
        } catch {
            print("Failed to fetch split for receipt \(receiptId): \(error)")
        }
    }

    /// Cache split data from an ExpenseSplit model
    func cacheSplit(_ split: ExpenseSplit) {
        let participants = split.participants.map { p in
            // Detect "Me" by isMe flag OR by name (for splits loaded from backend)
            let isMe = p.isMe || p.name.lowercased() == "me"
            return SplitParticipantInfo(
                id: p.id.uuidString,
                name: p.name,
                color: p.color,
                isMe: isMe
            )
        }

        var assignments: [String: [String]] = [:]
        for assignment in split.assignments {
            assignments[assignment.transactionId] = assignment.participantIds
        }

        let cached = CachedSplitData(
            splitId: split.id ?? "",
            receiptId: split.receiptId,
            participants: participants,
            assignments: assignments
        )

        cache[split.receiptId] = cached
    }

    /// Remove cached split for a receipt
    func removeSplit(for receiptId: String) {
        cache.removeValue(forKey: receiptId)
    }

    /// Clear all cached splits
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let expenseSplitSaved = Notification.Name("expenseSplitSaved")
}

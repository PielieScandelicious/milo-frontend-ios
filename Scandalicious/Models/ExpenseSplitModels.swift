//
//  ExpenseSplitModels.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 02/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Friend Color Palette

/// 8 vibrant colors for friend avatars
enum FriendColor: String, CaseIterable {
    case coral = "#FF6B6B"
    case oceanBlue = "#4ECDC4"
    case sunnyYellow = "#FFE66D"
    case forestGreen = "#95E879"
    case lavender = "#B388EB"
    case tangerine = "#FF9F45"
    case hotPink = "#FF69B4"
    case teal = "#00CED1"

    var color: Color {
        Color(hex: rawValue) ?? .gray
    }

    static func fromIndex(_ index: Int) -> FriendColor {
        let colors = FriendColor.allCases
        return colors[index % colors.count]
    }
}

// MARK: - Split Participant

struct SplitParticipant: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String  // Hex color
    var displayOrder: Int
    var isMe: Bool  // True for the default "Me" participant
    var customAmount: Double?  // Custom split amount (nil = equal split)

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case displayOrder = "display_order"
        case isMe = "is_me"
        case customAmount = "custom_amount"
    }

    init(id: UUID = UUID(), name: String, color: String, displayOrder: Int = 0, isMe: Bool = false, customAmount: Double? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.displayOrder = displayOrder
        self.isMe = isMe
        self.customAmount = customAmount
    }

    /// Static "Me" color - a distinct blue color
    static let meColor = "#3B82F6"

    /// Create the default "Me" participant
    static func createMe(displayOrder: Int = 0) -> SplitParticipant {
        SplitParticipant(
            name: "Me",
            color: meColor,
            displayOrder: displayOrder,
            isMe: true
        )
    }

    // Custom decoder to handle backend's string UUID format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Backend returns id as string, decode it to UUID
        let idString = try container.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid UUID string: \(idString)")
        }
        self.id = uuid

        self.name = try container.decode(String.self, forKey: .name)
        self.color = try container.decode(String.self, forKey: .color)
        self.displayOrder = try container.decode(Int.self, forKey: .displayOrder)
        self.isMe = try container.decodeIfPresent(Bool.self, forKey: .isMe) ?? false
        self.customAmount = try container.decodeIfPresent(Double.self, forKey: .customAmount)
    }

    /// Get Color from hex string
    var swiftUIColor: Color {
        Color(hex: color) ?? .gray
    }

    /// Get initials (first letters of first and last name, or first two letters)
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

// MARK: - Split Assignment

struct SplitAssignment: Identifiable, Codable, Equatable {
    let id: UUID
    let transactionId: String
    var participantIds: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case participantIds = "participant_ids"
    }

    init(id: UUID = UUID(), transactionId: String, participantIds: [String] = []) {
        self.id = id
        self.transactionId = transactionId
        self.participantIds = participantIds
    }

    // Custom decoder to handle backend's string UUID format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Backend returns id as string, decode it to UUID
        let idString = try container.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid UUID string: \(idString)")
        }
        self.id = uuid

        self.transactionId = try container.decode(String.self, forKey: .transactionId)
        self.participantIds = try container.decode([String].self, forKey: .participantIds)
    }
}

// MARK: - Expense Split

struct ExpenseSplit: Codable, Equatable {
    let id: String?
    let receiptId: String
    var participants: [SplitParticipant]
    var assignments: [SplitAssignment]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case receiptId = "receipt_id"
        case participants
        case assignments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String? = nil, receiptId: String, participants: [SplitParticipant] = [], assignments: [SplitAssignment] = []) {
        self.id = id
        self.receiptId = receiptId
        self.participants = participants
        self.assignments = assignments
        self.createdAt = nil
        self.updatedAt = nil
    }
}

// MARK: - Split Calculation Response

struct ParticipantTotal: Codable, Identifiable {
    let participantId: String
    let participantName: String
    let participantColor: String
    let totalAmount: Double
    let itemCount: Int
    let items: [SplitItem]

    var id: String { participantId }

    enum CodingKeys: String, CodingKey {
        case participantId = "participant_id"
        case participantName = "participant_name"
        case participantColor = "participant_color"
        case totalAmount = "total_amount"
        case itemCount = "item_count"
        case items
    }

    var swiftUIColor: Color {
        Color(hex: participantColor) ?? .gray
    }
}

struct SplitItem: Codable {
    let itemName: String
    let itemPrice: Double
    let shareAmount: Double

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case itemPrice = "item_price"
        case shareAmount = "share_amount"
    }
}

struct SplitCalculationResponse: Codable {
    let receiptId: String
    let receiptTotal: Double
    let participantTotals: [ParticipantTotal]

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case receiptTotal = "receipt_total"
        case participantTotals = "participant_totals"
    }
}

// MARK: - Recent Friend

struct RecentFriend: Identifiable, Codable {
    let id: String
    let name: String
    let color: String
    let lastUsedAt: Date?
    let useCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case lastUsedAt = "last_used_at"
        case useCount = "use_count"
    }

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

// MARK: - Share Text Response

struct ShareTextResponse: Codable {
    let text: String
}

// MARK: - Create Request Models

struct ExpenseSplitCreateRequest: Codable {
    let receiptId: String
    let participants: [ParticipantCreateRequest]
    let assignments: [AssignmentCreateRequest]

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case participants
        case assignments
    }
}

struct ParticipantCreateRequest: Codable {
    let name: String
    let color: String
    let customAmount: Double?
    let isMe: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case color
        case customAmount = "custom_amount"
        case isMe = "is_me"
    }

    init(name: String, color: String, customAmount: Double? = nil, isMe: Bool = false) {
        self.name = name
        self.color = color
        self.customAmount = customAmount
        self.isMe = isMe
    }
}

struct AssignmentCreateRequest: Codable {
    let transactionId: String
    let participantIds: [String]

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case participantIds = "participant_ids"
    }
}


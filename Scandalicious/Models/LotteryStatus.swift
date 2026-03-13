//
//  LotteryStatus.swift
//  Scandalicious
//
//  Created by Claude on 10/03/2026.
//

import Foundation

struct LotteryStatus: Codable {
    let eligible: Bool
    let hasInstagram: Bool
    let hasReceipt: Bool
    let hasShare: Bool
    let proofStatus: String?
    let postUrl: String?
    let currentMonth: String
    let prizeAmount: Int
    let drawingStatus: String
    let lastWinner: LotteryWinner?

    enum CodingKeys: String, CodingKey {
        case eligible
        case hasInstagram = "has_instagram"
        case hasReceipt = "has_receipt"
        case hasShare = "has_share"
        case proofStatus = "proof_status"
        case postUrl = "post_url"
        case currentMonth = "current_month"
        case prizeAmount = "prize_amount"
        case drawingStatus = "drawing_status"
        case lastWinner = "last_winner"
    }
}

struct LotteryWinner: Codable {
    let name: String
    let instagramHandle: String
    let month: String

    enum CodingKeys: String, CodingKey {
        case name
        case instagramHandle = "instagram_handle"
        case month
    }
}

//
//  GamificationModels.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Notification Names (Gamification)

extension Notification.Name {
    static let rewardEarned  = Notification.Name("gamification.rewardEarned")
    static let rewardClaimed = Notification.Name("gamification.rewardClaimed")
    static let spinCompleted = Notification.Name("gamification.spinCompleted")
    static let badgeUnlocked = Notification.Name("gamification.badgeUnlocked")
}

// MARK: - Codable Color Wrapper

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r); green = Double(g); blue = Double(b); alpha = Double(a)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Wallet Balance

struct WalletBalance: Codable {
    var cents: Int

    var euros: Double { Double(cents) / 100.0 }

    var formatted: String {
        String(format: "€%.2f", euros)
    }

    init(euros: Double) {
        self.cents = Int((euros * 100).rounded())
    }

    init(cents: Int) {
        self.cents = cents
    }

    mutating func add(euros amount: Double) {
        cents += Int((amount * 100).rounded())
    }
}

// MARK: - Streak

struct StreakData: Codable {
    var weekCount: Int
    var lastReceiptDate: Date?
    var hasShield: Bool
    var isAtRisk: Bool
    var claimableReward: StreakClaimableRewardResponse?
    var backendCycle: [StreakCycleEntryResponse]?

    enum CodingKeys: String, CodingKey {
        case weekCount, lastReceiptDate, hasShield, isAtRisk
    }

    var hasClaimableReward: Bool {
        claimableReward != nil
    }

    /// Reward schedule:
    /// Weeks 1-3: 1 spin | Week 4: €1
    /// Weeks 5-7: 2 spins | Week 8: €1
    /// Weeks 9-11: 3 spins | Week 12: €1
    /// After: 3 spins/week, €1 every 4th week
    static func weeklyReward(for week: Int) -> (label: String, icon: String, isCash: Bool, cashValue: Double) {
        guard week > 0 else {
            return ("1 spin", "arrow.trianglehead.2.clockwise.rotate.90", false, 0)
        }
        if week % 4 == 0 {
            return ("€1", "banknote.fill", true, 1.0)
        }
        let cycle = min((week - 1) / 4, 2)
        let spins = cycle + 1
        return ("\(spins) spin\(spins > 1 ? "s" : "")", "arrow.trianglehead.2.clockwise.rotate.90", false, 0)
    }

    var currentCycle: [(week: Int, label: String, icon: String, isCash: Bool, completed: Bool)] {
        if let bc = backendCycle {
            return bc.map { entry in
                let icon = entry.rewardType == "cash" ? "banknote.fill" : "arrow.trianglehead.2.clockwise.rotate.90"
                return (entry.week, entry.label, icon, entry.rewardType == "cash", entry.completed)
            }
        }
        // Fallback to local computation
        let cycleStart = lastCashWeek + 1
        return (0..<4).map { i in
            let w = cycleStart + i
            let r = StreakData.weeklyReward(for: w)
            return (w, r.label, r.icon, r.isCash, w <= weekCount)
        }
    }

    var lastCashWeek: Int {
        (weekCount / 4) * 4
    }

    var nextCashWeek: Int {
        lastCashWeek + 4
    }

    var weeksUntilCash: Int {
        nextCashWeek - weekCount
    }

    var flameScale: Double {
        let clamped = min(Double(weekCount), 52.0)
        return 1.0 + (clamped / 52.0) * 0.8
    }
}

// MARK: - Gold Tier

struct GoldTierStatus: Codable {
    var isGoldTier: Bool = true

    var displayName: String { isGoldTier ? "Gold" : "No Tier" }

    var gradientColors: [Color] {
        isGoldTier
            ? [Color(red: 1.0, green: 0.88, blue: 0.35),
               Color(red: 0.80, green: 0.60, blue: 0.0)]
            : [Color(white: 0.25), Color(white: 0.15)]
    }
}

// MARK: - Badge

struct Badge: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let iconColor: CodableColor
    var isUnlocked: Bool
    var unlockedAt: Date?

    static let allBadges: [Badge] = [
        Badge(id: "first_scan",    name: "First Scan",      description: "Upload your first receipt",               icon: "doc.text.viewfinder", iconColor: CodableColor(Color(red: 0.2, green: 0.8, blue: 0.4)),  isUnlocked: true,  unlockedAt: Date().addingTimeInterval(-86400 * 30)),
        Badge(id: "streak_2",      name: "Getting Started", description: "Reach a 2-week streak",                   icon: "flame.fill",          iconColor: CodableColor(.orange),                                  isUnlocked: true,  unlockedAt: Date().addingTimeInterval(-86400 * 14)),
        Badge(id: "streak_4",      name: "Consistent",      description: "Reach a 4-week streak",                   icon: "flame.fill",          iconColor: CodableColor(Color(red: 1.0, green: 0.5, blue: 0.0)),  isUnlocked: true,  unlockedAt: Date().addingTimeInterval(-86400 * 7)),
        Badge(id: "big_spender",   name: "Big Spender",     description: "Scan a receipt over €100",                icon: "banknote.fill",       iconColor: CodableColor(Color(red: 0.2, green: 0.8, blue: 0.4)),  isUnlocked: true,  unlockedAt: Date().addingTimeInterval(-86400 * 5)),
        Badge(id: "lucky_spin",    name: "Lucky Spin",      description: "Win €10 or more on the wheel",            icon: "sparkles",            iconColor: CodableColor(.yellow),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "streak_8",      name: "Dedicated",       description: "Reach an 8-week streak",                  icon: "flame.fill",          iconColor: CodableColor(.red),                                     isUnlocked: false, unlockedAt: nil),
        Badge(id: "coupon_buyer",  name: "Deal Hunter",     description: "Redeem your first coupon",                icon: "tag.fill",            iconColor: CodableColor(.purple),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "jackpot",       name: "Jackpot!",        description: "Hit the €1000 jackpot",                   icon: "crown.fill",          iconColor: CodableColor(.yellow),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "night_scanner", name: "Night Owl",       description: "Upload a receipt after 10 PM",            icon: "moon.fill",           iconColor: CodableColor(.indigo),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "collector",     name: "Collector",       description: "Scan receipts from 5 different stores",   icon: "storefront.fill",     iconColor: CodableColor(.cyan),                                    isUnlocked: false, unlockedAt: nil),
    ]
}

// MARK: - Spin Wheel

enum SpinSegmentType: String, Codable {
    case cash
    case mystery
    case tryAgain = "try_again"
    case doubleNext = "double_next"
    case jackpot
}

struct SpinSegment: Identifiable {
    let id: Int
    let label: String
    let value: Double
    let segmentType: SpinSegmentType
    let isJackpot: Bool
    let color: Color
    let icon: String?

    static let segments: [SpinSegment] = [
        SpinSegment(id: 0, label: "€0.10",        value: 0.10, segmentType: .cash,       isJackpot: false, color: Color(red: 0.3, green: 0.7, blue: 1.0),   icon: nil),
        SpinSegment(id: 1, label: "Mystery",       value: 0.0,  segmentType: .mystery,    isJackpot: false, color: Color(red: 0.6, green: 0.2, blue: 1.0),   icon: "gift.fill"),
        SpinSegment(id: 2, label: "€1",            value: 1.00, segmentType: .cash,       isJackpot: false, color: Color(red: 1.0, green: 0.65, blue: 0.0),  icon: nil),
        SpinSegment(id: 3, label: "2x",            value: 0.0,  segmentType: .doubleNext, isJackpot: false, color: Color(red: 0.3, green: 0.7, blue: 1.0),   icon: "bolt.fill"),
        SpinSegment(id: 4, label: "€0.50",         value: 0.50, segmentType: .cash,       isJackpot: false, color: Color(red: 0.2, green: 0.8, blue: 0.4),   icon: nil),
        SpinSegment(id: 5, label: "Retry",         value: 0.0,  segmentType: .tryAgain,   isJackpot: false, color: Color(red: 0.0, green: 0.8, blue: 0.7),   icon: "arrow.counterclockwise"),
        SpinSegment(id: 6, label: "€2",            value: 2.00, segmentType: .cash,       isJackpot: false, color: Color(red: 0.9, green: 0.2, blue: 0.4),   icon: nil),
        SpinSegment(id: 7, label: "Jackpot",        value: 5.00, segmentType: .jackpot,    isJackpot: true,  color: Color(red: 1.0, green: 0.84, blue: 0.0),  icon: "star.fill"),
    ]
}

struct SpinResult: Codable {
    let segmentIndex: Int
    let segmentLabel: String
    let segmentType: String
    let cashValue: Double
    let isJackpot: Bool
    let isDoubled: Bool
    let mysteryRevealValue: Double?
    let grantsFreeSpin: Bool
    let grantsDoubleNext: Bool
    let newBalance: Double
    let spinsRemaining: Int

    enum CodingKeys: String, CodingKey {
        case segmentIndex = "segment_index"
        case segmentLabel = "segment_label"
        case segmentType = "segment_type"
        case cashValue = "cash_value"
        case isJackpot = "is_jackpot"
        case isDoubled = "is_doubled"
        case mysteryRevealValue = "mystery_reveal_value"
        case grantsFreeSpin = "grants_free_spin"
        case grantsDoubleNext = "grants_double_next"
        case newBalance = "new_balance"
        case spinsRemaining = "spins_remaining"
    }
}

// MARK: - Mystery Bonus

enum MysteryBonusType {
    case cashBonus(Double)
    case spinToken
    case nothing

    // 25% cash, 10% spin, 65% nothing
    static func random() -> MysteryBonusType {
        let roll = Int.random(in: 0..<100)
        if roll < 25 { return .cashBonus([0.10, 0.20].randomElement()!) }
        if roll < 35 { return .spinToken }
        return .nothing
    }
}

// MARK: - Reward Event

struct RewardEvent {
    let storeName: String?
    let receiptAmount: Double?
    let coinsAwarded: Double
    let spinsAwarded: Int
    let mysteryBonus: MysteryBonusType

    static let userInfoKey = "gamification.rewardEvent"
}

// MARK: - Coupon

struct Coupon: Identifiable, Codable {
    let id: String
    let storeName: String
    let storeLogoColor: CodableColor
    let title: String
    let description: String
    let discountText: String
    let priceCents: Int
    let expiresAt: Date
    var isRedeemed: Bool
    var redeemedAt: Date?
    var qrPayload: String

    var priceEuros: Double { Double(priceCents) / 100.0 }
    var priceFormatted: String { String(format: "€%.2f", priceEuros) }
    var isExpired: Bool { Date() > expiresAt }

    static let mockCoupons: [Coupon] = [
        Coupon(id: "c1", storeName: "Lidl",         storeLogoColor: CodableColor(Color(red: 0.0, green: 0.5, blue: 1.0)),   title: "10% off Fresh Produce",  description: "Valid on all fresh produce at Lidl",          discountText: "10% off",   priceCents: 150, expiresAt: Date().addingTimeInterval(86400 * 14), isRedeemed: false, redeemedAt: nil, qrPayload: "LIDL-FRESH-10PCT"),
        Coupon(id: "c2", storeName: "Colruyt",      storeLogoColor: CodableColor(Color(red: 0.9, green: 0.1, blue: 0.1)),   title: "€2 Off Your Next Shop",  description: "Min. spend €20 at Colruyt",                   discountText: "€2 off",    priceCents: 100, expiresAt: Date().addingTimeInterval(86400 * 30), isRedeemed: false, redeemedAt: nil, qrPayload: "COL-2EUR-OFF"),
        Coupon(id: "c3", storeName: "Delhaize",     storeLogoColor: CodableColor(Color(red: 0.1, green: 0.6, blue: 0.2)),   title: "Free Yoghurt",           description: "Free Alpro yoghurt with any purchase",        discountText: "Free item", priceCents: 200, expiresAt: Date().addingTimeInterval(86400 * 7),  isRedeemed: false, redeemedAt: nil, qrPayload: "DEL-YOGHURT-FREE"),
        Coupon(id: "c4", storeName: "Aldi",         storeLogoColor: CodableColor(Color(red: 0.0, green: 0.45, blue: 0.85)), title: "€1 Off Bakery Items",    description: "Valid on all bakery items at Aldi",            discountText: "€1 off",    priceCents: 50,  expiresAt: Date().addingTimeInterval(86400 * 21), isRedeemed: false, redeemedAt: nil, qrPayload: "ALDI-BAKERY-1EUR"),
        Coupon(id: "c5", storeName: "Carrefour",    storeLogoColor: CodableColor(Color(red: 0.0, green: 0.45, blue: 0.8)),  title: "15% off Wine & Beer",    description: "Valid on selected wines and beers",            discountText: "15% off",   priceCents: 300, expiresAt: Date().addingTimeInterval(86400 * 10), isRedeemed: false, redeemedAt: nil, qrPayload: "CAR-WINE-15PCT"),
        Coupon(id: "c6", storeName: "Albert Heijn",  storeLogoColor: CodableColor(Color(red: 0.0, green: 0.55, blue: 0.95)), title: "Bonus Points x2",       description: "Double bonus points this weekend",             discountText: "2x points", priceCents: 75,  expiresAt: Date().addingTimeInterval(86400 * 3),  isRedeemed: false, redeemedAt: nil, qrPayload: "AH-DOUBLE-BONUS"),
    ]
}

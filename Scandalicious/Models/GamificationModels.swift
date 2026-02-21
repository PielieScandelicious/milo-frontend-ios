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
    static let spinCompleted = Notification.Name("gamification.spinCompleted")
    static let badgeUnlocked = Notification.Name("gamification.badgeUnlocked")
    static let tierChanged   = Notification.Name("gamification.tierChanged")
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

    /// Every week has a reward. Every 4th week is cash (increasing); other weeks are spins (increasing).
    static func weeklyReward(for week: Int) -> (label: String, icon: String, isCash: Bool, cashValue: Double) {
        if week > 0 && week % 4 == 0 {
            // Cash every 4 weeks: €0.50 base, doubles every 3 cash milestones
            let cashIndex = week / 4  // 1, 2, 3, 4, 5 ...
            let amounts: [Double] = [0.50, 1.0, 1.50, 2.0, 3.0, 5.0, 7.50, 10.0, 15.0, 20.0, 30.0, 50.0, 75.0]
            let amount = cashIndex <= amounts.count ? amounts[cashIndex - 1] : amounts.last!
            let label = amount >= 1.0 ? String(format: "€%.0f", amount) : String(format: "€%.2f", amount)
            return (label, "banknote.fill", true, amount)
        }
        // Spin weeks: base 1 spin, +1 every 4 weeks
        let spins = 1 + (week / 4)
        return ("\(spins) spin\(spins > 1 ? "s" : "")", "arrow.trianglehead.2.clockwise.rotate.90", false, 0)
    }

    var nextWeekReward: (label: String, icon: String, isCash: Bool, cashValue: Double) {
        StreakData.weeklyReward(for: weekCount + 1)
    }

    /// The current 4-week cycle (e.g. week 10 → cycle is W9, W10, W11, W12)
    /// Each entry includes whether it's completed (week <= weekCount)
    var currentCycle: [(week: Int, label: String, icon: String, isCash: Bool, completed: Bool)] {
        let cycleStart = lastCashWeek + 1  // first week after last cash
        return (0..<4).map { i in
            let w = cycleStart + i
            let r = StreakData.weeklyReward(for: w)
            return (w, r.label, r.icon, r.isCash, w <= weekCount)
        }
    }

    /// Last cash week that was reached (or 0 if none yet)
    var lastCashWeek: Int {
        (weekCount / 4) * 4
    }

    /// Next cash milestone week
    var nextCashWeek: Int {
        lastCashWeek + 4
    }

    /// Weeks remaining until next cash reward
    var weeksUntilCash: Int {
        nextCashWeek - weekCount
    }

    var flameScale: Double {
        let clamped = min(Double(weekCount), 52.0)
        return 1.0 + (clamped / 52.0) * 0.8
    }
}

// MARK: - Tier

enum UserTier: String, Codable, CaseIterable {
    case bronze  = "Bronze"
    case silver  = "Silver"
    case gold    = "Gold"
    case diamond = "Diamond"

    var minReceipts: Int {
        switch self {
        case .bronze:  return 0
        case .silver:  return 5
        case .gold:    return 8
        case .diamond: return 12
        }
    }

    var next: UserTier? {
        switch self {
        case .bronze:  return .silver
        case .silver:  return .gold
        case .gold:    return .diamond
        case .diamond: return nil
        }
    }

    var multiplier: Double {
        switch self {
        case .bronze:  return 1.0
        case .silver:  return 1.1
        case .gold:    return 1.25
        case .diamond: return 1.5
        }
    }

    var spinsPerReceipt: Int {
        switch self {
        case .bronze:  return 1
        case .silver:  return 2
        case .gold:    return 3
        case .diamond: return 5
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .bronze:
            return [Color(red: 0.90, green: 0.60, blue: 0.35),
                    Color(red: 0.60, green: 0.35, blue: 0.15)]
        case .silver:
            return [Color(red: 0.85, green: 0.85, blue: 0.90),
                    Color(red: 0.55, green: 0.55, blue: 0.60)]
        case .gold:
            return [Color(red: 1.0, green: 0.88, blue: 0.35),
                    Color(red: 0.80, green: 0.60, blue: 0.0)]
        case .diamond:
            return [Color(red: 0.6, green: 0.9, blue: 1.0),
                    Color(red: 0.3, green: 0.6, blue: 0.95)]
        }
    }

    var icon: String {
        switch self {
        case .bronze:  return "medal.fill"
        case .silver:  return "medal.fill"
        case .gold:    return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    var bonusLabel: String {
        switch self {
        case .bronze:  return "1x"
        case .silver:  return "1.1x"
        case .gold:    return "1.25x"
        case .diamond: return "1.5x"
        }
    }

    var perks: [String] {
        switch self {
        case .bronze:  return ["1 spin/receipt", "Base earnings"]
        case .silver:  return ["2 spins/receipt", "+10% bonus"]
        case .gold:    return ["3 spins/receipt", "+25% bonus"]
        case .diamond: return ["5 spins/receipt", "+50% bonus"]
        }
    }
}

struct TierProgress: Codable {
    var currentTier: UserTier
    var receiptsThisMonth: Int

    var progressToNext: Double {
        guard let next = currentTier.next else { return 1.0 }
        let range = next.minReceipts - currentTier.minReceipts
        let current = receiptsThisMonth - currentTier.minReceipts
        guard range > 0 else { return 1.0 }
        return max(0, min(1.0, Double(current) / Double(range)))
    }

    var receiptsNeededForNextTier: Int {
        guard let next = currentTier.next else { return 0 }
        return max(0, next.minReceipts - receiptsThisMonth)
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
        Badge(id: "silver_tier",   name: "Silver Member",   description: "Reach Silver tier",                       icon: "medal.fill",          iconColor: CodableColor(Color(red: 0.7, green: 0.7, blue: 0.75)), isUnlocked: true,  unlockedAt: Date().addingTimeInterval(-86400 * 10)),
        Badge(id: "big_spender",   name: "Big Spender",     description: "Scan a receipt over €100",                icon: "banknote.fill",       iconColor: CodableColor(Color(red: 0.2, green: 0.8, blue: 0.4)),  isUnlocked: true,  unlockedAt: Date().addingTimeInterval(-86400 * 5)),
        Badge(id: "lucky_spin",    name: "Lucky Spin",      description: "Win €10 or more on the wheel",            icon: "sparkles",            iconColor: CodableColor(.yellow),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "streak_8",      name: "Dedicated",       description: "Reach an 8-week streak",                  icon: "flame.fill",          iconColor: CodableColor(.red),                                     isUnlocked: false, unlockedAt: nil),
        Badge(id: "gold_tier",     name: "Gold Member",     description: "Reach Gold tier",                         icon: "medal.fill",          iconColor: CodableColor(Color(red: 1.0, green: 0.84, blue: 0.0)), isUnlocked: false, unlockedAt: nil),
        Badge(id: "coupon_buyer",  name: "Deal Hunter",     description: "Redeem your first coupon",                icon: "tag.fill",            iconColor: CodableColor(.purple),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "jackpot",       name: "Jackpot!",        description: "Hit the €1000 jackpot",                   icon: "crown.fill",          iconColor: CodableColor(.yellow),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "night_scanner", name: "Night Owl",       description: "Upload a receipt after 10 PM",            icon: "moon.fill",           iconColor: CodableColor(.indigo),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "collector",     name: "Collector",       description: "Scan receipts from 5 different stores",   icon: "storefront.fill",     iconColor: CodableColor(.cyan),                                    isUnlocked: false, unlockedAt: nil),
    ]
}

// MARK: - Spin Wheel

struct SpinSegment: Identifiable {
    let id: Int
    let label: String
    let value: Double
    let isJackpot: Bool
    let color: Color

    static let segments: [SpinSegment] = [
        SpinSegment(id: 0, label: "€0.20",    value: 0.20,    isJackpot: false, color: Color(red: 0.3, green: 0.7, blue: 1.0)),
        SpinSegment(id: 1, label: "€0.50",    value: 0.50,    isJackpot: false, color: Color(red: 0.45, green: 0.15, blue: 0.85)),
        SpinSegment(id: 2, label: "€1",       value: 1.00,    isJackpot: false, color: Color(red: 0.2, green: 0.8, blue: 0.4)),
        SpinSegment(id: 3, label: "€2",       value: 2.00,    isJackpot: false, color: Color(red: 1.0, green: 0.65, blue: 0.0)),
        SpinSegment(id: 4, label: "€5",       value: 5.00,    isJackpot: false, color: Color(red: 0.9, green: 0.2, blue: 0.4)),
        SpinSegment(id: 5, label: "€10",      value: 10.00,   isJackpot: false, color: Color(red: 0.3, green: 0.7, blue: 1.0)),
        SpinSegment(id: 6, label: "€50",      value: 50.00,   isJackpot: false, color: Color(red: 1.0, green: 0.84, blue: 0.0)),
        SpinSegment(id: 7, label: "€1000",    value: 1000.00, isJackpot: true,  color: Color(red: 1.0, green: 0.3, blue: 0.5)),
    ]

    // Weights: [35, 25, 18, 10, 6, 3, 2, 1] — jackpot is 1%
    static let weights: [Int] = [35, 25, 18, 10, 6, 3, 2, 1]

    static func randomResult() -> SpinSegment {
        let total = weights.reduce(0, +)
        var roll = Int.random(in: 0..<total)
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return segments[index] }
        }
        return segments[0]
    }
}

struct SpinResult: Codable {
    let segmentIndex: Int
    let valueEuros: Double
    let isJackpot: Bool
    let timestamp: Date
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

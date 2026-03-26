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

// MARK: - Badge

struct Badge: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let iconColor: CodableColor
    var isUnlocked: Bool
    var unlockedAt: Date?
    var progress: Double?       // 0.0–1.0 progress toward unlock
    var progressLabel: String?  // e.g. "3/5 stores"

    static func == (lhs: Badge, rhs: Badge) -> Bool {
        lhs.id == rhs.id && lhs.isUnlocked == rhs.isUnlocked && lhs.progress == rhs.progress
    }

    /// Ordered by estimated time to achieve (easiest → hardest).
    /// The grid shows the first 9; the test panel shows all.
    static let allBadges: [Badge] = [
        // Row 1 – Instant / first session
        Badge(id: "first_scan",        name: "First Scan",       description: "Upload your first receipt",              icon: "doc.text.viewfinder",  iconColor: CodableColor(Color(red: 0.2, green: 0.8, blue: 0.4)),  isUnlocked: false, unlockedAt: nil),
        Badge(id: "night_scanner",     name: "Night Owl",        description: "Upload a receipt after 10 PM",           icon: "moon.fill",            iconColor: CodableColor(.indigo),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "big_spender",       name: "Big Spender",      description: "Scan a receipt over €100",               icon: "banknote.fill",        iconColor: CodableColor(Color(red: 0.2, green: 0.8, blue: 0.4)),  isUnlocked: false, unlockedAt: nil),
        // Row 2 – First few weeks
        Badge(id: "streak_2",          name: "Getting Started",  description: "Reach a 2-week streak",                  icon: "flag.fill",            iconColor: CodableColor(.orange),                                  isUnlocked: false, unlockedAt: nil),
        Badge(id: "weekend_warrior",   name: "Weekend Warrior",  description: "Scan on both Saturday and Sunday",       icon: "sun.max.fill",         iconColor: CodableColor(Color(red: 1.0, green: 0.6, blue: 0.2)),  isUnlocked: false, unlockedAt: nil),
        Badge(id: "lucky_spin",        name: "Lucky Spin",       description: "Win €1 or more on the wheel",            icon: "sparkles",             iconColor: CodableColor(.yellow),                                  isUnlocked: false, unlockedAt: nil),
        // Row 3 – ~1 month
        Badge(id: "collector",         name: "Collector",        description: "Scan receipts from 5 different stores",  icon: "storefront.fill",      iconColor: CodableColor(.cyan),                                    isUnlocked: false, unlockedAt: nil),
        Badge(id: "streak_4",          name: "Consistent",       description: "Reach a 4-week streak",                  icon: "flame.fill",           iconColor: CodableColor(Color(red: 1.0, green: 0.5, blue: 0.0)),  isUnlocked: false, unlockedAt: nil),
        Badge(id: "budget_boss",       name: "Budget Boss",      description: "Finish a month under budget",            icon: "chart.pie.fill",       iconColor: CodableColor(Color(red: 0.3, green: 0.7, blue: 1.0)),  isUnlocked: false, unlockedAt: nil),
        // Row 4 – ~2 months (beyond grid)
        Badge(id: "streak_8",          name: "Dedicated",        description: "Reach an 8-week streak",                 icon: "flame.fill",           iconColor: CodableColor(.red),                                     isUnlocked: false, unlockedAt: nil),
        Badge(id: "penny_pincher",     name: "Penny Pincher",    description: "Finish a month 20%+ under budget",       icon: "scissors",             iconColor: CodableColor(Color(red: 0.0, green: 0.8, blue: 0.7)),  isUnlocked: false, unlockedAt: nil),
        Badge(id: "grocery_guru",      name: "Grocery Guru",     description: "Scan 20 grocery receipts",               icon: "carrot.fill",          iconColor: CodableColor(Color(red: 0.4, green: 0.85, blue: 0.3)), isUnlocked: false, unlockedAt: nil),
        // Row 5 – ~3 months
        Badge(id: "social_butterfly",  name: "Social Butterfly", description: "Refer 3 friends who join Milo",          icon: "person.3.fill",        iconColor: CodableColor(Color(red: 0.85, green: 0.3, blue: 0.9)), isUnlocked: false, unlockedAt: nil),
        Badge(id: "streak_12",         name: "Marathon Streak",  description: "Reach a 12-week streak",                 icon: "figure.run",           iconColor: CodableColor(Color(red: 1.0, green: 0.35, blue: 0.2)), isUnlocked: false, unlockedAt: nil),
        Badge(id: "category_explorer", name: "Category Explorer", description: "Buy from 8 different categories",      icon: "square.grid.3x3.fill", iconColor: CodableColor(Color(red: 0.5, green: 0.6, blue: 1.0)),  isUnlocked: false, unlockedAt: nil),
        // Row 6 – Long-term
        Badge(id: "spin_master",       name: "Spin Master",      description: "Complete 50 spins",                      icon: "arrow.trianglehead.2.clockwise.rotate.90", iconColor: CodableColor(Color(red: 0.6, green: 0.2, blue: 1.0)), isUnlocked: false, unlockedAt: nil),
        Badge(id: "century_club",      name: "Century Club",     description: "Scan 100 receipts",                      icon: "trophy.fill",          iconColor: CodableColor(Color(red: 1.0, green: 0.84, blue: 0.0)), isUnlocked: false, unlockedAt: nil),
        Badge(id: "jackpot",           name: "Jackpot!",         description: "Hit the jackpot on the wheel",           icon: "crown.fill",           iconColor: CodableColor(.yellow),                                  isUnlocked: false, unlockedAt: nil),
    ]

    /// Number of badges shown in the Achievements grid card.
    static let gridDisplayCount = 6
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
        SpinSegment(id: 0, label: "€0.10",   value: 0.10, segmentType: .cash,       isJackpot: false, color: Color(red: 0.3, green: 0.7, blue: 1.0),  icon: nil),
        SpinSegment(id: 1, label: "Mystery",  value: 0.0,  segmentType: .mystery,    isJackpot: false, color: Color(red: 0.6, green: 0.2, blue: 1.0),  icon: "gift.fill"),
        SpinSegment(id: 2, label: "€1",       value: 1.00, segmentType: .cash,       isJackpot: false, color: Color(red: 1.0, green: 0.65, blue: 0.0), icon: nil),
        SpinSegment(id: 3, label: "2x",       value: 0.0,  segmentType: .doubleNext, isJackpot: false, color: Color(red: 0.3, green: 0.7, blue: 1.0),  icon: "bolt.fill"),
        SpinSegment(id: 4, label: "€0.50",    value: 0.50, segmentType: .cash,       isJackpot: false, color: Color(red: 0.2, green: 0.8, blue: 0.4),  icon: nil),
        SpinSegment(id: 5, label: "Retry",    value: 0.0,  segmentType: .tryAgain,   isJackpot: false, color: Color(red: 0.0, green: 0.8, blue: 0.7),  icon: "arrow.counterclockwise"),
        SpinSegment(id: 6, label: "€2",       value: 2.00, segmentType: .cash,       isJackpot: false, color: Color(red: 0.9, green: 0.2, blue: 0.4),  icon: nil),
        SpinSegment(id: 7, label: "Jackpot",  value: 5.00, segmentType: .jackpot,    isJackpot: true,  color: Color(red: 1.0, green: 0.84, blue: 0.0), icon: "star.fill"),
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


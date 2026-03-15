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

// MARK: - Wallet Balance (Milo Points)
// Conversion: 10,000 pts = €10.00  |  1 pt = €0.001

struct WalletBalance: Codable {
    /// Points balance (primary currency)
    var points: Int

    /// Euro value computed from points
    var euros: Double { Double(points) / 1000.0 }

    var formatted: String { "\(points) pts" }

    var euroFormatted: String { String(format: "= €%.2f", euros) }

    /// Minimum payout threshold
    static let minimumPayoutPoints = 10_000

    var canWithdraw: Bool { points >= WalletBalance.minimumPayoutPoints }

    // Legacy initializers kept for compat
    init(euros: Double) {
        self.points = Int((euros * 1000).rounded())
    }

    init(points: Int) {
        self.points = points
    }

    // Legacy cents-based init (converts to points)
    init(cents: Int) {
        self.points = cents * 10  // 100 cents = 1 euro = 1000 points, so 1 cent = 10 points
    }

    mutating func add(points amount: Int) {
        points += amount
    }

    mutating func add(euros amount: Double) {
        points += Int((amount * 1000).rounded())
    }
}

// MARK: - Streak

struct StreakData: Codable {
    var weekCount: Int
    var streakLevel: Int  // 1 = Level 1 (first month), 2 = Level 2 (continuous)
    var lastReceiptDate: Date?
    var hasShield: Bool
    var isAtRisk: Bool
    var claimableReward: StreakClaimableRewardResponse?
    var backendCycle: [StreakCycleEntryResponse]?

    enum CodingKeys: String, CodingKey {
        case weekCount, lastReceiptDate, hasShield, isAtRisk, streakLevel
    }

    init(weekCount: Int = 0, streakLevel: Int = 1, lastReceiptDate: Date? = nil,
         hasShield: Bool = false, isAtRisk: Bool = false) {
        self.weekCount = weekCount
        self.streakLevel = streakLevel
        self.lastReceiptDate = lastReceiptDate
        self.hasShield = hasShield
        self.isAtRisk = isAtRisk
    }

    var hasClaimableReward: Bool { claimableReward != nil }

    var isLevel2: Bool { streakLevel >= 2 }

    var levelDisplayName: String { isLevel2 ? "Level 2" : "Level 1" }

    /// Reward schedule per level.
    static func weeklyReward(for cyclePosition: Int, level: Int) -> (label: String, icon: String, isPoints: Bool, points: Int, isSpin: Bool, spinType: String) {
        let pos = ((cyclePosition - 1) % 4) + 1
        if level == 1 {
            switch pos {
            case 1: return ("Geen beloning", "xmark.circle", false, 0, false, "")
            case 2: return ("1 Standaard Spin", "arrow.trianglehead.2.clockwise.rotate.90", false, 0, true, "standard")
            case 3: return ("150 pts", "star.fill", true, 150, false, "")
            case 4: return ("1 Premium Spin + 50 pts", "crown.fill", true, 50, true, "premium")
            default: return ("", "", false, 0, false, "")
            }
        } else {
            switch pos {
            case 1: return ("150 pts", "star.fill", true, 150, false, "")
            case 2: return ("1 Standaard Spin + 100 pts", "arrow.trianglehead.2.clockwise.rotate.90", true, 100, true, "standard")
            case 3: return ("1 Standaard Spin + 150 pts", "arrow.trianglehead.2.clockwise.rotate.90", true, 150, true, "standard")
            case 4: return ("1 Premium Spin + 200 pts", "crown.fill", true, 200, true, "premium")
            default: return ("", "", false, 0, false, "")
            }
        }
    }

    var currentCycle: [(week: Int, label: String, icon: String, isCash: Bool, completed: Bool)] {
        if let bc = backendCycle {
            return bc.map { entry in
                let icon: String
                switch entry.rewardType {
                case "spins", "mixed": icon = entry.label.contains("Premium") ? "crown.fill" : "arrow.trianglehead.2.clockwise.rotate.90"
                case "points": icon = "star.fill"
                default: icon = "xmark.circle"
                }
                return (entry.week, entry.label, icon, entry.rewardType == "points", entry.completed)
            }
        }
        let cycleStart = max(weekCount - ((weekCount - 1) % 4), 1)
        return (0..<4).map { i in
            let w = cycleStart + i
            let r = StreakData.weeklyReward(for: i + 1, level: streakLevel)
            return (w, r.label, r.icon, r.isPoints, w <= weekCount)
        }
    }

    var cyclePosition: Int {
        weekCount > 0 ? ((weekCount - 1) % 4) + 1 : 0
    }

    var flameScale: Double {
        let clamped = min(Double(weekCount), 52.0)
        return 1.0 + (clamped / 52.0) * 0.8
    }
}

// MARK: - Tier Level (Bronze / Silver / Gold)

enum TierLevel: String, Codable, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold   = "gold"

    var displayName: String {
        switch self {
        case .bronze: return "Brons"
        case .silver: return "Zilver"
        case .gold:   return "Goud"
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold:   return "crown.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .bronze:
            return [Color(red: 0.80, green: 0.50, blue: 0.20),
                    Color(red: 0.60, green: 0.35, blue: 0.10)]
        case .silver:
            return [Color(white: 0.75), Color(white: 0.55)]
        case .gold:
            return [Color(red: 1.0, green: 0.88, blue: 0.35),
                    Color(red: 0.80, green: 0.60, blue: 0.0)]
        }
    }

    var spinDescription: String {
        switch self {
        case .bronze: return "1 Standaard Spin"
        case .silver: return "1 Standaard Spin + 75 pts"
        case .gold:   return "1 Premium Spin"
        }
    }

    var requirement: String {
        switch self {
        case .bronze: return "< 4 tickets/maand"
        case .silver: return "4-9 tickets/maand"
        case .gold:   return "10+ tickets/maand"
        }
    }

    // Legacy helper
    var isGoldTier: Bool { self == .gold }
}

// MARK: - Kickstart Progress

struct KickstartProgress: Codable {
    var ticketsCompleted: Int
    var totalTickets: Int
    var isCompleted: Bool

    var progressFraction: Double {
        guard totalTickets > 0 else { return 0 }
        return Double(ticketsCompleted) / Double(totalTickets)
    }

    enum CodingKeys: String, CodingKey {
        case ticketsCompleted = "tickets_completed"
        case totalTickets = "total_tickets"
        case isCompleted = "is_completed"
    }
}

// MARK: - Spin Type

enum SpinWheelType: String, Codable {
    case standard = "standard"
    case premium  = "premium"

    var displayName: String {
        switch self {
        case .standard: return "Standaard Spin"
        case .premium:  return "Premium Spin"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .premium:  return "crown.fill"
        }
    }

    var evPoints: Int {
        switch self {
        case .standard: return 100
        case .premium:  return 200
        }
    }
}

// Legacy alias for code that references GoldTierStatus
typealias GoldTierStatus = TierLevel

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
    static let gridDisplayCount = 9
}

// MARK: - Spin Wheel

enum SpinSegmentType: String, Codable {
    case cash
    case mystery
    case tryAgain = "try_again"
    case jackpot
    // Legacy (no longer used but kept for decoding old responses)
    case doubleNext = "double_next"
}

struct SpinSegment: Identifiable {
    let id: Int
    let label: String
    let pointsValue: Int      // Points (0 for try_again/mystery)
    let segmentType: SpinSegmentType
    let isJackpot: Bool
    let color: Color
    let icon: String?

    // Standard wheel segments (EV ~100 pts)
    static let standardSegments: [SpinSegment] = [
        SpinSegment(id: 0, label: "50 pts",   pointsValue: 50,   segmentType: .cash,     isJackpot: false, color: Color(red: 0.3, green: 0.7, blue: 1.0),  icon: nil),
        SpinSegment(id: 1, label: "Mystery",  pointsValue: 0,    segmentType: .mystery,  isJackpot: false, color: Color(red: 0.6, green: 0.2, blue: 1.0),  icon: "gift.fill"),
        SpinSegment(id: 2, label: "200 pts",  pointsValue: 200,  segmentType: .cash,     isJackpot: false, color: Color(red: 1.0, green: 0.65, blue: 0.0), icon: nil),
        SpinSegment(id: 3, label: "Try Again",pointsValue: 0,    segmentType: .tryAgain, isJackpot: false, color: Color(red: 0.0, green: 0.8, blue: 0.7),  icon: "arrow.counterclockwise"),
        SpinSegment(id: 4, label: "100 pts",  pointsValue: 100,  segmentType: .cash,     isJackpot: false, color: Color(red: 0.2, green: 0.8, blue: 0.4),  icon: nil),
        SpinSegment(id: 5, label: "150 pts",  pointsValue: 150,  segmentType: .cash,     isJackpot: false, color: Color(red: 0.9, green: 0.4, blue: 0.7),  icon: nil),
        SpinSegment(id: 6, label: "75 pts",   pointsValue: 75,   segmentType: .cash,     isJackpot: false, color: Color(red: 0.4, green: 0.6, blue: 1.0),  icon: nil),
        SpinSegment(id: 7, label: "JACKPOT",  pointsValue: 1000, segmentType: .jackpot,  isJackpot: true,  color: Color(red: 1.0, green: 0.84, blue: 0.0), icon: "star.fill"),
    ]

    // Premium wheel segments (EV ~200 pts) — gold/amber palette
    static let premiumSegments: [SpinSegment] = [
        SpinSegment(id: 0, label: "100 pts",  pointsValue: 100,  segmentType: .cash,     isJackpot: false, color: Color(red: 1.0, green: 0.7, blue: 0.2),  icon: nil),
        SpinSegment(id: 1, label: "Mystery",  pointsValue: 0,    segmentType: .mystery,  isJackpot: false, color: Color(red: 0.7, green: 0.3, blue: 1.0),  icon: "gift.fill"),
        SpinSegment(id: 2, label: "400 pts",  pointsValue: 400,  segmentType: .cash,     isJackpot: false, color: Color(red: 1.0, green: 0.5, blue: 0.0),  icon: nil),
        SpinSegment(id: 3, label: "Try Again",pointsValue: 0,    segmentType: .tryAgain, isJackpot: false, color: Color(red: 0.9, green: 0.7, blue: 0.0),  icon: "arrow.counterclockwise"),
        SpinSegment(id: 4, label: "200 pts",  pointsValue: 200,  segmentType: .cash,     isJackpot: false, color: Color(red: 0.85, green: 0.6, blue: 0.1), icon: nil),
        SpinSegment(id: 5, label: "300 pts",  pointsValue: 300,  segmentType: .cash,     isJackpot: false, color: Color(red: 1.0, green: 0.4, blue: 0.1),  icon: nil),
        SpinSegment(id: 6, label: "150 pts",  pointsValue: 150,  segmentType: .cash,     isJackpot: false, color: Color(red: 0.95, green: 0.75, blue: 0.1),icon: nil),
        SpinSegment(id: 7, label: "JACKPOT",  pointsValue: 2000, segmentType: .jackpot,  isJackpot: true,  color: Color(red: 1.0, green: 0.84, blue: 0.0), icon: "star.fill"),
    ]

    static func segments(for spinType: SpinWheelType) -> [SpinSegment] {
        spinType == .premium ? premiumSegments : standardSegments
    }
}

struct SpinResult: Codable {
    let segmentIndex: Int
    let segmentLabel: String
    let segmentType: String
    let pointsValue: Int
    let isJackpot: Bool
    let mysteryRevealValue: Int?
    let grantsFreeSpin: Bool
    let spinType: String
    let newPointsBalance: Int
    let standardSpinsRemaining: Int
    let premiumSpinsRemaining: Int

    // Legacy fields (still returned for backward compat)
    let cashValue: Double?
    let isDoubled: Bool?
    let grantsDoubleNext: Bool?
    let newBalance: Double?
    let spinsRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case segmentIndex = "segment_index"
        case segmentLabel = "segment_label"
        case segmentType = "segment_type"
        case pointsValue = "points_value"
        case isJackpot = "is_jackpot"
        case mysteryRevealValue = "mystery_reveal_value"
        case grantsFreeSpin = "grants_free_spin"
        case spinType = "spin_type"
        case newPointsBalance = "new_points_balance"
        case standardSpinsRemaining = "standard_spins_remaining"
        case premiumSpinsRemaining = "premium_spins_remaining"
        case cashValue = "cash_value"
        case isDoubled = "is_doubled"
        case grantsDoubleNext = "grants_double_next"
        case newBalance = "new_balance"
        case spinsRemaining = "spins_remaining"
    }
}

// MARK: - Mystery Bonus

enum MysteryBonusType {
    case pointsBonus(Int)
    case spinToken
    case nothing

    // 25% points, 10% spin, 65% nothing
    static func random(spinType: SpinWheelType = .standard) -> MysteryBonusType {
        let roll = Int.random(in: 0..<100)
        if roll < 25 {
            let candidates = spinType == .premium ? [100, 200] : [50, 100]
            return .pointsBonus(candidates.randomElement()!)
        }
        if roll < 35 { return .spinToken }
        return .nothing
    }

    // Legacy helper
    var cashBonusEuros: Double? {
        if case .pointsBonus(let pts) = self { return Double(pts) / 1000.0 }
        return nil
    }
}

// MARK: - Reward Event

struct RewardEvent {
    let storeName: String?
    let receiptAmount: Double?

    // Points breakdown
    let pointsTotal: Int
    let fixedPoints: Int
    let groteKarPoints: Int
    let kickstartBonusPoints: Int
    let spinType: SpinWheelType?
    let isKickstart: Bool
    let isStreakSaver: Bool

    // Legacy / misc
    let spinsAwarded: Int
    let mysteryBonus: MysteryBonusType

    static let userInfoKey = "gamification.rewardEvent"

    // Legacy computed
    var coinsAwarded: Double { Double(pointsTotal) / 1000.0 }

    init(storeName: String? = nil,
         receiptAmount: Double? = nil,
         pointsTotal: Int = 0,
         fixedPoints: Int = 0,
         groteKarPoints: Int = 0,
         kickstartBonusPoints: Int = 0,
         spinType: SpinWheelType? = nil,
         isKickstart: Bool = false,
         isStreakSaver: Bool = false,
         spinsAwarded: Int = 0,
         mysteryBonus: MysteryBonusType = .nothing) {
        self.storeName = storeName
        self.receiptAmount = receiptAmount
        self.pointsTotal = pointsTotal
        self.fixedPoints = fixedPoints
        self.groteKarPoints = groteKarPoints
        self.kickstartBonusPoints = kickstartBonusPoints
        self.spinType = spinType
        self.isKickstart = isKickstart
        self.isStreakSaver = isStreakSaver
        self.spinsAwarded = spinsAwarded
        self.mysteryBonus = mysteryBonus
    }
}


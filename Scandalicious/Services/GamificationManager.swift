//
//  GamificationManager.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth

@MainActor
class GamificationManager: ObservableObject {
    static let shared = GamificationManager()

    // MARK: - Published State

    @Published private(set) var wallet: WalletBalance = WalletBalance(euros: 0)
    @Published private(set) var streak: StreakData = StreakData(weekCount: 0, lastReceiptDate: nil, hasShield: false, isAtRisk: false)
    @Published private(set) var tierProgress: TierProgress = TierProgress(currentTier: .bronze, receiptsThisMonth: 0)
    @Published private(set) var badges: [Badge] = Badge.allBadges
    @Published private(set) var spinsAvailable: Int = 0
    @Published private(set) var ownedCoupons: [Coupon] = []
    @Published private(set) var lastUnlockedBadge: Badge? = nil
    @Published private(set) var lastSpinResult: SpinResult? = nil

    // MARK: - Private

    private let userDefaults = UserDefaults.standard
    private var currentUserId: String?

    // MARK: - Init

    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.handleUserChange(user)
            }
        }

        if let user = Auth.auth().currentUser {
            handleUserChange(user)
        }
    }

    // MARK: - User Management

    private func handleUserChange(_ user: FirebaseAuth.User?) {
        let newUserId = user?.uid
        if newUserId != currentUserId {
            currentUserId = newUserId
            if newUserId != nil {
                loadState()
            } else {
                resetToDefaults()
            }
        }
    }

    private var keyPrefix: String {
        guard let uid = currentUserId else { return "gamification_anonymous" }
        return "gamification_\(uid)"
    }

    // MARK: - State Management

    private func resetToDefaults() {
        wallet = WalletBalance(euros: 0)
        streak = StreakData(weekCount: 0, lastReceiptDate: nil, hasShield: false, isAtRisk: false)
        tierProgress = TierProgress(currentTier: .bronze, receiptsThisMonth: 0)
        badges = Badge.allBadges.map { var b = $0; b.isUnlocked = false; b.unlockedAt = nil; return b }
        spinsAvailable = 0
        ownedCoupons = []
    }

    private func loadState() {
        let prefix = keyPrefix
        let decoder = JSONDecoder()

        if let data = userDefaults.data(forKey: "\(prefix)_wallet"),
           let decoded = try? decoder.decode(WalletBalance.self, from: data) {
            wallet = decoded
        } else {
            wallet = WalletBalance(euros: 4.50)
        }

        if let data = userDefaults.data(forKey: "\(prefix)_streak"),
           let decoded = try? decoder.decode(StreakData.self, from: data) {
            streak = decoded
            checkStreakStatus()
        } else {
            streak = StreakData(weekCount: 3, lastReceiptDate: Date().addingTimeInterval(-86400 * 5), hasShield: false, isAtRisk: false)
        }

        if let data = userDefaults.data(forKey: "\(prefix)_tier"),
           let decoded = try? decoder.decode(TierProgress.self, from: data) {
            tierProgress = decoded
        } else {
            tierProgress = TierProgress(currentTier: .silver, receiptsThisMonth: 6)
        }

        spinsAvailable = userDefaults.integer(forKey: "\(prefix)_spins")
        if !userDefaults.bool(forKey: "\(prefix)_initialized") {
            spinsAvailable = 2
        }

        if let data = userDefaults.data(forKey: "\(prefix)_badges"),
           let decoded = try? decoder.decode([Badge].self, from: data) {
            badges = decoded
        } else {
            badges = Badge.allBadges
        }

        if let data = userDefaults.data(forKey: "\(prefix)_ownedCoupons"),
           let decoded = try? decoder.decode([Coupon].self, from: data) {
            ownedCoupons = decoded
        }

        userDefaults.set(true, forKey: "\(prefix)_initialized")
        saveState()
    }

    private func saveState() {
        let prefix = keyPrefix
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(wallet)       { userDefaults.set(data, forKey: "\(prefix)_wallet") }
        if let data = try? encoder.encode(streak)       { userDefaults.set(data, forKey: "\(prefix)_streak") }
        if let data = try? encoder.encode(tierProgress) { userDefaults.set(data, forKey: "\(prefix)_tier") }
        if let data = try? encoder.encode(badges)       { userDefaults.set(data, forKey: "\(prefix)_badges") }
        if let data = try? encoder.encode(ownedCoupons) { userDefaults.set(data, forKey: "\(prefix)_ownedCoupons") }
        userDefaults.set(spinsAvailable, forKey: "\(prefix)_spins")
    }

    // MARK: - Public API

    func awardReceiptReward(storeName: String?, receiptAmount: Double?) -> RewardEvent {
        let baseAmount = 0.50
        let bonus = MysteryBonusType.random()

        let multiplied = baseAmount * tierProgress.currentTier.multiplier
        wallet.add(euros: multiplied)

        switch bonus {
        case .cashBonus(let amount):
            wallet.add(euros: amount)
        case .spinToken:
            spinsAvailable += 1
        case .nothing:
            break
        }

        // Award spins based on tier
        spinsAvailable += tierProgress.currentTier.spinsPerReceipt

        updateStreakForReceipt()
        incrementReceiptCount()
        saveState()

        return RewardEvent(
            storeName: storeName,
            receiptAmount: receiptAmount,
            coinsAwarded: multiplied,
            spinsAwarded: tierProgress.currentTier.spinsPerReceipt,
            mysteryBonus: bonus
        )
    }

    func spinWheel() -> SpinResult? {
        guard spinsAvailable > 0 else { return nil }
        spinsAvailable -= 1

        let segment = SpinSegment.randomResult()
        wallet.add(euros: segment.value)

        let result = SpinResult(
            segmentIndex: segment.id,
            valueEuros: segment.value,
            isJackpot: segment.isJackpot,
            timestamp: Date()
        )
        lastSpinResult = result

        if segment.isJackpot {
            unlockBadgeIfNeeded(id: "jackpot")
        }
        if segment.value >= 10.0 {
            unlockBadgeIfNeeded(id: "lucky_spin")
        }

        saveState()
        NotificationCenter.default.post(name: .spinCompleted, object: nil)
        return result
    }

    func redeemCoupon(_ coupon: Coupon) -> Bool {
        guard wallet.cents >= coupon.priceCents else { return false }

        wallet.cents -= coupon.priceCents
        var purchased = coupon
        purchased.isRedeemed = false
        purchased.redeemedAt = Date()
        ownedCoupons.append(purchased)

        unlockBadgeIfNeeded(id: "coupon_buyer")
        saveState()
        return true
    }

    func checkStreakStatus() {
        guard let lastDate = streak.lastReceiptDate else { return }
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        streak.isAtRisk = daysSince >= 5 && daysSince < 7
        saveState()
    }

    // MARK: - Private Helpers

    private func updateStreakForReceipt() {
        let now = Date()
        streak.lastReceiptDate = now
        streak.isAtRisk = false
        streak.weekCount += 1

        if streak.weekCount == 2 { unlockBadgeIfNeeded(id: "streak_2") }
        if streak.weekCount == 4 { unlockBadgeIfNeeded(id: "streak_4") }
        if streak.weekCount == 8 { unlockBadgeIfNeeded(id: "streak_8") }

        // Award weekly streak reward
        let reward = StreakData.weeklyReward(for: streak.weekCount)
        if reward.isCash {
            wallet.add(euros: reward.cashValue)
        } else {
            let spinStr = reward.label.components(separatedBy: " ").first ?? "1"
            spinsAvailable += Int(spinStr) ?? 1
        }
    }

    private func incrementReceiptCount() {
        tierProgress.receiptsThisMonth += 1

        let newTier = tierForReceipts(tierProgress.receiptsThisMonth)
        if newTier != tierProgress.currentTier {
            tierProgress.currentTier = newTier
            if newTier == .gold    { unlockBadgeIfNeeded(id: "gold_tier") }
            if newTier == .silver  { unlockBadgeIfNeeded(id: "silver_tier") }

            NotificationCenter.default.post(
                name: .tierChanged,
                object: nil,
                userInfo: ["to": newTier.rawValue]
            )
        }
    }

    private func tierForReceipts(_ count: Int) -> UserTier {
        if count >= 12 { return .diamond }
        if count >= 8  { return .gold }
        if count >= 5  { return .silver }
        return .bronze
    }

    private func unlockBadgeIfNeeded(id: String) {
        guard let index = badges.firstIndex(where: { $0.id == id }),
              !badges[index].isUnlocked else { return }

        badges[index].isUnlocked = true
        badges[index].unlockedAt = Date()
        lastUnlockedBadge = badges[index]

        NotificationCenter.default.post(
            name: .badgeUnlocked,
            object: nil,
            userInfo: ["badgeId": id]
        )
    }
}

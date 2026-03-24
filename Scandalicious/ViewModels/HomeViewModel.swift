//
//  HomeViewModel.swift
//  Scandalicious
//
//  Central view model for the redesigned home tab.
//  Supports multi-receipt processing with per-receipt cashback reveal.
//

import SwiftUI

// MARK: - Recent Receipt (backed by backend cashback data)

struct RecentReceipt: Identifiable {
    let id: String
    let storeName: String
    let storeColor: Color
    let totalAmount: Double
    let cashbackAmount: Double
    let spinsAwarded: Int
    let date: Date
    var isReferralReward: Bool = false
    var isStreakReward: Bool = false

    /// Map a backend cashback transaction to a displayable receipt.
    static func from(_ tx: CashbackTransactionResponse) -> RecentReceipt {
        let store = GroceryStore.allCases.first {
            tx.storeName?.localizedCaseInsensitiveContains($0.displayName) == true
        }
        let color = store?.accentColor ?? .gray
        let streakOrange = Color(red: 1.0, green: 0.5, blue: 0.0)

        // Parse ISO 8601 created_at
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: tx.createdAt)
            ?? ISO8601DateFormatter().date(from: tx.createdAt)
            ?? Date()

        let displayName: String
        let displayColor: Color
        if tx.isStreakReward {
            displayName = tx.storeName ?? "Streak Reward"
            displayColor = streakOrange
        } else if tx.isReferralReward {
            displayName = "Referral Bonus"
            displayColor = Color(red: 0.35, green: 0.65, blue: 1.0)
        } else {
            displayName = tx.storeName?.localizedCapitalized ?? "Store"
            displayColor = color
        }

        return RecentReceipt(
            id: tx.id,
            storeName: displayName,
            storeColor: displayColor,
            totalAmount: tx.receiptTotal,
            cashbackAmount: tx.cashbackAmount,
            spinsAwarded: tx.spinsAwarded,
            date: date,
            isReferralReward: tx.isReferralReward,
            isStreakReward: tx.isStreakReward
        )
    }
}

// MARK: - Home View Model

@Observable
class HomeViewModel {
    // Reward reveal (per-receipt claim)
    var showCashbackReveal: Bool = false
    var animatedCashbackValue: Double = 0  // animated euro value for legacy
    var animatedPointsValue: Int = 0       // animated points total
    var showConfetti: Bool = false
    var claimingReceiptId: String?
    var processingStoreName: String = ""
    var processingStoreColor: Color = .white
    var processingAmount: Double = 0

    // Points breakdown for reward overlay
    var pointsTotal: Int = 0
    var fixedPoints: Int = 0
    var groteKarPoints: Int = 0
    var kickstartBonusPoints: Int = 0
    var spinType: SpinWheelType? = nil
    var isKickstart: Bool = false
    var isStreakSaver: Bool = false

    // Legacy kept for CashbackRevealOverlay compat
    var cashbackAmount: Double = 0
    var spinsAwarded: Int = 0
    var isGoldTier: Bool = true

    /// Tier used by the overlay for label text.
    /// Normally mirrors GamificationManager; overridden by the test stub.
    var displayTierLevel: TierLevel = GamificationManager.shared.tierLevel

    // Referral reward reveal
    var showReferralReveal: Bool = false
    var referralEurosAwarded: Double = 0
    var referralSpinsAwarded: Int = 0
    var animatedReferralValue: Double = 0
    var showReferralConfetti: Bool = false

    // Mini game
    var showMiniGame: Bool = false

    // Recent receipts (from backend)
    var recentReceipts: [RecentReceipt] = []

    private var completionObserver: Any?
    private var rewardClaimedObserver: Any?

    init() {
        loadRecentReceipts()
        observeReceiptCompletion()
        observeRewardClaimed()
    }

    deinit {
        if let observer = completionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = rewardClaimedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Upload from Camera

    func uploadAndProcess(image: UIImage) {
        Task {
            do {
                let result = try await ReceiptUploadService.shared.uploadReceipt(image: image)
                await MainActor.run {
                    if case .accepted(let accepted) = result {
                        ReceiptProcessingManager.shared.addReceipt(accepted)
                    }
                }
            } catch {
                print("[HomeViewModel] Upload failed: \(error)")
            }
        }
    }

    // MARK: - Claim Reward (per-receipt)

    func claimReward(for receipt: ProcessingReceipt) {
        claimingReceiptId = receipt.id
        processingStoreName = receipt.storeName?.localizedCapitalized ?? "Store"
        processingAmount = receipt.totalAmount ?? 0
        cashbackAmount = 0
        pointsTotal = 0
        fixedPoints = 0
        groteKarPoints = 0
        kickstartBonusPoints = 0
        spinType = nil
        isKickstart = false
        isStreakSaver = false
        animatedCashbackValue = 0
        animatedPointsValue = 0
        showConfetti = false

        if let store = GroceryStore.allCases.first(where: {
            receipt.storeName?.localizedCaseInsensitiveContains($0.displayName) == true
        }) {
            processingStoreColor = store.accentColor
        } else {
            processingStoreColor = .white
        }

        // Claim the reward on the backend (PENDING → CONFIRMED, credits wallet),
        // then fetch updated summary so the overlay shows the correct amount.
        Task { @MainActor in
            _ = try? await CashbackAPIService.shared.claim(receiptId: receipt.id)
            await fetchCashbackForReceipt(receiptId: receipt.id)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showCashbackReveal = true
            }
        }
    }

    // MARK: - Claim Referral Reward

    func claimReferralReward() {
        Task { @MainActor in
            do {
                let result = try await GamificationManager.shared.claimReferralReward()
                referralEurosAwarded = result.eurosCredited
                referralSpinsAwarded = result.spinsCredited
                animatedReferralValue = 0
                showReferralConfetti = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    showReferralReveal = true
                }
            } catch {
                print("[HomeViewModel] Referral claim failed: \(error)")
            }
        }
    }

    func dismissReferralReveal() {
        withAnimation(.easeIn(duration: 0.25)) {
            showReferralReveal = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showReferralConfetti = false
            self.animatedReferralValue = 0
            // Reload recent receipts from backend (includes claimed referral entries)
            self.loadRecentReceipts()
        }
    }

    func dismissReward() {
        let receiptId = claimingReceiptId
        withAnimation(.easeIn(duration: 0.25)) {
            showCashbackReveal = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showConfetti = false
            self.animatedCashbackValue = 0
            // Dismiss the claimed receipt from the processing list
            if let id = receiptId {
                ReceiptProcessingManager.shared.dismiss(id)
            }
            self.claimingReceiptId = nil
        }
    }

    // MARK: - Receipt Completion Observer

    private func observeReceiptCompletion() {
        completionObserver = NotificationCenter.default.addObserver(
            forName: .receiptUploadedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Refresh recent receipts when any receipt completes
            let receiptId = notification.userInfo?["receiptId"] as? String
            Task { @MainActor in
                await self.fetchCashbackForReceipt(receiptId: receiptId, updateUI: false)
            }
        }
    }

    // MARK: - Reward Claimed Observer

    private func observeRewardClaimed() {
        rewardClaimedObserver = NotificationCenter.default.addObserver(
            forName: .rewardClaimed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadRecentReceipts()
        }
    }

    // MARK: - Backend Integration

    private func fetchCashbackForReceipt(receiptId: String?, updateUI: Bool = true) async {
        do {
            let summary = try await CashbackAPIService.shared.getSummary()

            if updateUI {
                let tx: CashbackTransactionResponse?
                if let receiptId {
                    tx = summary.recentTransactions.first(where: { $0.receiptId == receiptId })
                        ?? summary.recentTransactions.first
                } else {
                    tx = summary.recentTransactions.first
                }
                if let tx {
                    self.pointsTotal          = tx.pointsTotal
                    self.fixedPoints          = tx.fixedPoints
                    self.groteKarPoints       = tx.groteKarPoints
                    self.kickstartBonusPoints = tx.kickstartBonusPoints
                    self.spinType             = tx.spinWheelType
                    self.isKickstart          = tx.isKickstart
                    self.isStreakSaver        = tx.isStreakSaver
                    self.spinsAwarded         = tx.spinsAwarded
                    self.cashbackAmount       = tx.cashbackAmount
                } else {
                    self.pointsTotal = 0; self.spinsAwarded = 0; self.cashbackAmount = 0
                }
                self.isGoldTier = summary.isGoldTier
                self.displayTierLevel = TierLevel(rawValue: summary.tierLevel) ?? GamificationManager.shared.tierLevel
            }

            // Refresh recent receipts list
            updateRecentReceipts(from: summary.recentTransactions)

            // Sync wallet via GamificationManager
            GamificationManager.shared.fetchAndSyncWallet()

        } catch {
            print("[HomeViewModel] Failed to fetch cashback: \(error)")
            if updateUI {
                self.cashbackAmount = self.processingAmount * 0.005
                self.spinsAwarded = 0
            }
        }
    }

    func loadRecentReceipts() {
        Task { @MainActor in
            do {
                let summary = try await CashbackAPIService.shared.getSummary()
                updateRecentReceipts(from: summary.recentTransactions)
                GamificationManager.shared.fetchAndSyncWallet()
            } catch {
                print("[HomeViewModel] Failed to load recent receipts: \(error)")
            }
            // Also refresh referral info (unclaimed reward state)
            GamificationManager.shared.fetchReferralInfo()
        }
    }

    private func updateRecentReceipts(from transactions: [CashbackTransactionResponse]) {
        self.recentReceipts = transactions.map { RecentReceipt.from($0) }
            .sorted { $0.date > $1.date }
    }
}

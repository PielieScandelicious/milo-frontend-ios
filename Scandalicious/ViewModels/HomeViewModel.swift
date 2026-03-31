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
    var isBrandCashback: Bool = false
    var brandImageSystemName: String? = nil

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

    static func fromBrandCashback(_ entry: EarnedBrandCashbackEntry) -> RecentReceipt {
        let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
        return RecentReceipt(
            id: "brand-\(entry.id)",
            storeName: entry.productName,
            storeColor: cashbackGreen,
            totalAmount: 0,
            cashbackAmount: entry.cashbackAmount,
            spinsAwarded: 0,
            date: entry.earnedAt,
            isBrandCashback: true,
            brandImageSystemName: entry.imageSystemName
        )
    }
}

// MARK: - Home View Model

@Observable
class HomeViewModel {
    // Reward reveal (per-receipt claim)
    var showCashbackReveal: Bool = false
    var animatedCashbackValue: Double = 0
    var showConfetti: Bool = false
    var claimingReceiptId: String?
    var processingStoreName: String = ""
    var processingStoreColor: Color = .white
    var processingAmount: Double = 0
    var cashbackAmount: Double = 0
    var spinsAwarded: Int = 0
    var isGoldTier: Bool = true

    // Mini game
    var showMiniGame: Bool = false

    // Recent receipts (from backend)
    var recentReceipts: [RecentReceipt] = []

    // Recent uploaded receipts list (from /receipts endpoint)
    var uploadedReceipts: [APIReceipt] = []
    var isLoadingReceipts: Bool = false

    private var completionObserver: Any?
    private var rewardClaimedObserver: Any?
    private var brandCashbackObserver: Any?

    init() {
        // Seed from prefetched cache if available
        let cache = BudgetTabPreloadCache.shared
        if cache.hasPreloaded {
            if let summary = cache.cashbackSummary {
                var receipts = summary.recentTransactions.map { RecentReceipt.from($0) }
                let brandReceipts = cache.earnedBrandDeals.map { RecentReceipt.fromBrandCashback($0) }
                receipts.append(contentsOf: brandReceipts)
                self.recentReceipts = receipts.sorted { $0.date > $1.date }

                GamificationManager.shared.syncWalletWithBackend(
                    balance: summary.balance.currentBalance,
                    isGoldTier: summary.isGoldTier,
                    spins: summary.balance.spinsAvailable
                )
            }
            if !cache.recentUploadedReceipts.isEmpty {
                self.uploadedReceipts = cache.recentUploadedReceipts
            } else {
                loadUploadedReceipts()
            }
        } else {
            loadRecentReceipts()
            loadUploadedReceipts()
        }

        observeReceiptCompletion()
        observeRewardClaimed()
        observeBrandCashbackEarned()
    }

    deinit {
        if let observer = completionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = rewardClaimedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = brandCashbackObserver {
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
        animatedCashbackValue = 0
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
            let receiptId = notification.userInfo?["receiptId"] as? String
            Task { @MainActor in
                await self.fetchCashbackForReceipt(receiptId: receiptId, updateUI: false)
                self.loadUploadedReceipts()
                // Auto-dismiss the processing card after 2s.
                // Brand cashback overlay (if earned) fires independently via BrandCashbackViewModel.
                try? await Task.sleep(for: .seconds(2))
                if let receiptId {
                    ReceiptProcessingManager.shared.dismiss(receiptId)
                }
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

    // MARK: - Brand Cashback Earned Observer

    private func observeBrandCashbackEarned() {
        brandCashbackObserver = NotificationCenter.default.addObserver(
            forName: .brandCashbackEarned,
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
                // Find matching transaction by receipt_id
                if let receiptId,
                   let tx = summary.recentTransactions.first(where: { $0.receiptId == receiptId }) {
                    self.cashbackAmount = tx.cashbackAmount
                    self.spinsAwarded = tx.spinsAwarded
                } else if let latest = summary.recentTransactions.first {
                    self.cashbackAmount = latest.cashbackAmount
                    self.spinsAwarded = latest.spinsAwarded
                } else {
                    self.cashbackAmount = self.processingAmount * 0.005
                    self.spinsAwarded = 0
                }
                self.isGoldTier = summary.isGoldTier
            }

            // Refresh recent receipts list
            updateRecentReceipts(from: summary.recentTransactions)

            // Sync wallet, gold tier, and spins with backend
            GamificationManager.shared.syncWalletWithBackend(
                balance: summary.balance.currentBalance,
                isGoldTier: summary.isGoldTier,
                spins: summary.balance.spinsAvailable
            )

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
                async let summaryTask = CashbackAPIService.shared.getSummary()
                async let earnedDealsTask = BrandCashbackService.shared.fetchEarnedDeals()

                let summary = try await summaryTask
                let earnedDeals = await earnedDealsTask

                var receipts = summary.recentTransactions.map { RecentReceipt.from($0) }
                let brandReceipts = earnedDeals.map { RecentReceipt.fromBrandCashback($0) }
                receipts.append(contentsOf: brandReceipts)
                self.recentReceipts = receipts.sorted { $0.date > $1.date }

                GamificationManager.shared.syncWalletWithBackend(
                    balance: summary.balance.currentBalance,
                    isGoldTier: summary.isGoldTier,
                    spins: summary.balance.spinsAvailable
                )
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

    // MARK: - Uploaded Receipts List

    func loadUploadedReceipts() {
        Task { @MainActor in
            isLoadingReceipts = true
            do {
                let filters = ReceiptFilters(page: 1, pageSize: 15)
                let response = try await AnalyticsAPIService.shared.getReceipts(filters: filters)
                self.uploadedReceipts = response.receipts
            } catch {
                print("[HomeViewModel] Failed to load uploaded receipts: \(error)")
            }
            isLoadingReceipts = false
        }
    }
}

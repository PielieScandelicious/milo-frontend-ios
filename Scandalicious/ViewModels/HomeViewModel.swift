//
//  HomeViewModel.swift
//  Scandalicious
//
//  Central view model for the redesigned home tab.
//  Drives the processing card UI with a 38-second progress bar,
//  triggered by camera scan or share extension uploads.
//

import SwiftUI

// MARK: - Recent Receipt (backed by backend cashback data)

struct RecentReceipt: Identifiable {
    let id: String
    let storeName: String
    let storeColor: Color
    let totalAmount: Double
    let cashbackAmount: Double
    let date: Date

    /// Map a backend cashback transaction to a displayable receipt.
    static func from(_ tx: CashbackTransactionResponse) -> RecentReceipt {
        let store = GroceryStore.allCases.first {
            tx.storeName?.localizedCaseInsensitiveContains($0.displayName) == true
        }
        let color = store?.accentColor ?? .gray

        // Parse ISO 8601 created_at
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: tx.createdAt)
            ?? ISO8601DateFormatter().date(from: tx.createdAt)
            ?? Date()

        return RecentReceipt(
            id: tx.id,
            storeName: tx.storeName ?? "Store",
            storeColor: color,
            totalAmount: tx.receiptTotal,
            cashbackAmount: tx.cashbackAmount,
            date: date
        )
    }
}

// MARK: - Processing Phase

enum HomeProcessingPhase: Equatable {
    case idle
    case processing
    case done
    case claiming

    static func == (lhs: HomeProcessingPhase, rhs: HomeProcessingPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.processing, .processing),
             (.done, .done), (.claiming, .claiming):
            return true
        default:
            return false
        }
    }
}

// MARK: - Home View Model

@Observable
class HomeViewModel {
    // Processing
    var processingPhase: HomeProcessingPhase = .idle
    var processingProgress: Double = 0
    var processingStoreName: String = ""
    var processingStoreColor: Color = .white
    var processingAmount: Double = 0
    var cashbackAmount: Double = 0

    // Reward reveal
    var showCashbackReveal: Bool = false
    var animatedCashbackValue: Double = 0
    var showConfetti: Bool = false

    // Mini game
    var showMiniGame: Bool = false

    // Recent receipts (from backend)
    var recentReceipts: [RecentReceipt] = []

    // Private
    private var processingTimer: Timer?
    private var processingStartTime: Date?
    private var receiptCompleted: Bool = false
    private var completionObserver: Any?

    /// Average receipt processing time in seconds.
    private let processingDuration: Double = 38.0

    var isProcessing: Bool {
        processingPhase == .processing
    }

    init() {
        loadRecentReceipts()
        observeReceiptCompletion()
    }

    deinit {
        if let observer = completionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        processingTimer?.invalidate()
    }

    // MARK: - Upload from Camera

    func uploadAndProcess(image: UIImage) {
        guard processingPhase == .idle else { return }

        prepareProcessingState()
        startProgressBar()

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

    // MARK: - Triggered by Share Extension

    func startProcessingForShareExtension() {
        guard processingPhase == .idle else { return }

        prepareProcessingState()

        // Pick up elapsed time from the active receipt so the bar starts where it should be
        if let activeReceipt = ReceiptProcessingManager.shared.processingReceipts.first(where: { !$0.isTerminal }) {
            let elapsed = Date().timeIntervalSince(activeReceipt.startedAt)
            startProgressBar(fromElapsed: elapsed)
        } else {
            startProgressBar()
        }
    }

    // MARK: - Demo (for testing)

    func startProcessing() {
        guard processingPhase == .idle else { return }
        prepareProcessingState()
        startProgressBar()
    }

    // MARK: - Progress Bar

    private func prepareProcessingState() {
        processingStoreName = "Processing..."
        processingStoreColor = .white
        processingAmount = 0
        cashbackAmount = 0
    }

    /// Estimated progress using an asymptotic curve: rises quickly at first,
    /// then slows down and never reaches 1.0 on its own.
    /// Only backend completion drives it to 100%.
    private func estimatedProgress(elapsed: Double) -> Double {
        // 1 - e^(-k*t) where k is calibrated so we reach ~90% at processingDuration
        let k = 2.303 / processingDuration
        return 1.0 - exp(-k * elapsed)
    }

    private func startProgressBar(fromElapsed initialElapsed: Double = 0) {
        receiptCompleted = false
        processingStartTime = Date().addingTimeInterval(-initialElapsed)
        processingProgress = estimatedProgress(elapsed: initialElapsed)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            processingPhase = .processing
        }

        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            DispatchQueue.main.async {
                guard let start = self.processingStartTime else { return }
                let elapsed = Date().timeIntervalSince(start)

                if self.receiptCompleted {
                    // Backend confirmed done — animate to 100% and finish
                    timer.invalidate()
                    self.processingTimer = nil
                    withAnimation(.easeOut(duration: 0.4)) {
                        self.processingProgress = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.onProcessingComplete()
                    }
                } else {
                    // Asymptotic curve — keeps rising but never hits 1.0
                    withAnimation(.linear(duration: 0.1)) {
                        self.processingProgress = self.estimatedProgress(elapsed: elapsed)
                    }
                }
            }
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
            guard self.processingPhase == .processing else { return }

            // Update with real data from notification
            if let storeName = notification.userInfo?["storeName"] as? String {
                self.processingStoreName = storeName
                if let store = GroceryStore.allCases.first(where: {
                    storeName.localizedCaseInsensitiveContains($0.displayName)
                }) {
                    self.processingStoreColor = store.accentColor
                }
            }
            if let amount = notification.userInfo?["receiptAmount"] as? Double {
                self.processingAmount = amount
            }

            let receiptId = notification.userInfo?["receiptId"] as? String

            // Fetch real cashback from backend
            Task { @MainActor in
                await self.fetchCashbackForReceipt(receiptId: receiptId)
                self.receiptCompleted = true
            }
        }
    }

    // MARK: - Backend Integration

    private func fetchCashbackForReceipt(receiptId: String?) async {
        do {
            let summary = try await CashbackAPIService.shared.getSummary()

            // Find matching transaction by receipt_id
            if let receiptId,
               let tx = summary.recentTransactions.first(where: { $0.receiptId == receiptId }) {
                self.cashbackAmount = tx.cashbackAmount
            } else if let latest = summary.recentTransactions.first {
                // Fallback: most recent transaction
                self.cashbackAmount = latest.cashbackAmount
            } else {
                // Last resort: minimum rate estimate
                self.cashbackAmount = self.processingAmount * 0.005
            }

            // Refresh recent receipts list
            updateRecentReceipts(from: summary.recentTransactions)

            // Sync wallet with backend balance
            GamificationManager.shared.syncWalletWithBackend(balance: summary.balance.currentBalance)

        } catch {
            print("[HomeViewModel] Failed to fetch cashback: \(error)")
            // Fallback: minimum rate
            self.cashbackAmount = self.processingAmount * 0.005
        }
    }

    func loadRecentReceipts() {
        Task { @MainActor in
            do {
                let summary = try await CashbackAPIService.shared.getSummary()
                updateRecentReceipts(from: summary.recentTransactions)
                GamificationManager.shared.syncWalletWithBackend(balance: summary.balance.currentBalance)
            } catch {
                print("[HomeViewModel] Failed to load recent receipts: \(error)")
            }
        }
    }

    private func updateRecentReceipts(from transactions: [CashbackTransactionResponse]) {
        self.recentReceipts = transactions.map { RecentReceipt.from($0) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Processing Complete

    private func onProcessingComplete() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            processingPhase = .done
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func claimReward() {
        guard processingPhase == .done else { return }
        processingPhase = .claiming
        animatedCashbackValue = 0
        showConfetti = false

        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            showCashbackReveal = true
        }
    }

    func dismissReward() {
        withAnimation(.easeIn(duration: 0.25)) {
            showCashbackReveal = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.processingPhase = .idle
            }
            self.showConfetti = false
            self.animatedCashbackValue = 0
        }
    }
}

//
//  HomeViewModel.swift
//  Scandalicious
//
//  Central view model for the redesigned home tab.
//  Uses mock data only — no backend calls.
//

import SwiftUI

// MARK: - Mock Receipt

struct MockReceipt: Identifiable {
    let id = UUID()
    let storeName: String
    let storeColor: Color
    let totalAmount: Double
    let cashbackAmount: Double
    let date: Date
    let itemCount: Int
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

    // Recent receipts
    var recentReceipts: [MockReceipt] = []

    // Private
    private var processingTimer: Timer?
    private var processingStartTime: Date?

    var isProcessing: Bool {
        processingPhase == .processing
    }

    init() {
        generateMockReceipts()
    }

    // MARK: - Processing Flow

    func startProcessing() {
        guard processingPhase == .idle else { return }

        let store = GroceryStore.allCases.randomElement()!
        processingStoreName = store.displayName
        processingStoreColor = store.accentColor
        processingAmount = Double.random(in: 15...120)
        cashbackAmount = processingAmount * Double.random(in: 0.005...0.015)
        processingProgress = 0
        processingStartTime = Date()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            processingPhase = .processing
        }

        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            DispatchQueue.main.async {
                guard let start = self.processingStartTime else { return }
                let elapsed = Date().timeIntervalSince(start)
                let duration: Double = 20.0

                if elapsed >= duration {
                    self.processingProgress = 1.0
                    timer.invalidate()
                    self.processingTimer = nil
                    self.onProcessingComplete()
                } else {
                    withAnimation(.linear(duration: 0.1)) {
                        self.processingProgress = min(elapsed / duration, 1.0)
                    }
                }
            }
        }
    }

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

    // MARK: - Mock Data

    func generateMockReceipts() {
        let stores = GroceryStore.allCases
        recentReceipts = (0..<10).map { i in
            let store = stores[i % stores.count]
            let amount = Double(Int.random(in: 1250...14500)) / 100.0
            return MockReceipt(
                storeName: store.displayName,
                storeColor: store.accentColor,
                totalAmount: amount,
                cashbackAmount: amount * Double.random(in: 0.005...0.015),
                date: Date().addingTimeInterval(-Double(i) * 86400 * Double.random(in: 0.5...2.5)),
                itemCount: Int.random(in: 3...28)
            )
        }.sorted { $0.date > $1.date }
    }
}

//
//  BrandCashbackViewModel.swift
//  Scandalicious
//
//  Orchestrates the brand cashback feature:
//  - Splits deals into available / my deals / earned
//  - Observes receipt completion to trigger mock matching
//  - Manages the CashbackEarnedOverlay state
//

import Foundation
import Combine
import SwiftUI

@MainActor
class BrandCashbackViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var availableDeals: [BrandCashbackDeal] = []
    @Published private(set) var myDeals: [BrandCashbackDeal] = []
    @Published private(set) var earnedDeals: [BrandCashbackDeal] = []

    @Published var showEarnedOverlay = false
    @Published private(set) var lastEarnedAmount: Double = 0
    @Published private(set) var lastEarnedDealName: String = ""

    // MARK: - Private

    private let service = BrandCashbackService.shared
    private var cancellables = Set<AnyCancellable>()
    private var receiptObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        observeServiceChanges()
        observeReceiptNotification()
        Task { await loadDeals() }
    }

    deinit {
        if let observer = receiptObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public

    func loadDeals() async {
        await service.loadDeals()
        refreshDeals()
    }

    func claimDeal(_ deal: BrandCashbackDeal) {
        Task {
            await service.claimDeal(id: deal.id)
            refreshDeals()
        }
    }

    func unclaimDeal(_ deal: BrandCashbackDeal) {
        Task {
            await service.unclaimDeal(id: deal.id)
            refreshDeals()
        }
    }

    func dismissEarnedOverlay() {
        withAnimation(.easeOut(duration: 0.3)) {
            showEarnedOverlay = false
        }
        service.clearEarnedDeal()
        // Refresh to remove newly-earned deal from the list
        Task { await loadDeals() }
    }

    // MARK: - Private Helpers

    private func refreshDeals() {
        let deals = service.allDeals
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            availableDeals = deals.filter { $0.status == .available && !$0.isExpired }
            myDeals = deals.filter { $0.status == .claimed || $0.status == .pending }
            earnedDeals = []
        }
    }

    /// Observe BrandCashbackService.$lastEarnedDeal via Combine to show overlay.
    private func observeServiceChanges() {
        service.$lastEarnedDeal
            .receive(on: RunLoop.main)
            .sink { [weak self] earned in
                guard let self, let earned else { return }
                self.lastEarnedAmount = earned.earned
                self.lastEarnedDealName = earned.deal.productName
                self.refreshDeals()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.showEarnedOverlay = true
                }
            }
            .store(in: &cancellables)

        // Also refresh when allDeals changes (claim/unclaim)
        service.$allDeals
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshDeals() }
            .store(in: &cancellables)
    }

    /// Wait 3 seconds after a receipt finishes, then refresh deals to detect new earnings.
    /// (GamificationManager syncs the wallet at 1s, cashback check runs in backend at ~2s.)
    private func observeReceiptNotification() {
        receiptObserver = NotificationCenter.default.addObserver(
            forName: .receiptUploadedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let receiptId = notification.userInfo?["receiptId"] as? String ?? UUID().uuidString

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                await self?.service.refreshAndDetectEarnings(receiptId: receiptId)
            }
        }
    }
}

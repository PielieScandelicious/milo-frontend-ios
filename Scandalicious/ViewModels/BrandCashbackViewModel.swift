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

/// Lightweight payload for the in-app "your receipt was reviewed" toast.
struct DeniedToast: Identifiable, Equatable {
    let id = UUID()
    let brandName: String
    let productName: String
    let reason: String
}

@MainActor
class BrandCashbackViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var availableDeals: [BrandCashbackDeal] = []
    @Published private(set) var myDeals: [BrandCashbackDeal] = []
    @Published private(set) var earnedDeals: [BrandCashbackDeal] = []
    /// Unified, original-order list shown in the Cashback feed. Includes
    /// every non-expired, non-`.earned` deal in the order returned by the
    /// backend. Status changes flip the contents of a row but never reshuffle.
    @Published private(set) var campaigns: [BrandCashbackDeal] = []

    @Published var showEarnedOverlay = false
    @Published private(set) var lastEarnedAmount: Double = 0
    @Published private(set) var lastEarnedDealName: String = ""
    @Published private(set) var lastEarnedImageUrl: URL? = nil

    /// Set briefly when a previously-pending review is denied. The view
    /// observes this and renders a transient toast.
    @Published var deniedToast: DeniedToast?

    // MARK: - Private

    private let service = BrandCashbackService.shared
    private var cancellables = Set<AnyCancellable>()
    private var receiptObserver: NSObjectProtocol?
    private var denialObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        observeServiceChanges()
        observeReceiptNotification()
        observeDenialNotification()
        observeForeground()
        Task { await loadDeals() }
    }

    deinit {
        for observer in [receiptObserver, denialObserver, foregroundObserver] {
            if let observer { NotificationCenter.default.removeObserver(observer) }
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
            // My-deals priority: pending review > partially earned > plain claimed.
            // The first puts a decision-pending item front-and-centre; the
            // second celebrates progress and nudges repeat purchase before the
            // user moves on to claims they haven't started on yet.
            let claimedAndPending = deals.filter {
                $0.status == .claimed || $0.status == .pendingReview
            }
            myDeals = claimedAndPending.sorted { lhs, rhs in
                myDealsPriority(lhs) < myDealsPriority(rhs)
            }
            earnedDeals = []
            campaigns = deals
        }
    }

    /// Lower number = higher position in the My Deals rail.
    private func myDealsPriority(_ deal: BrandCashbackDeal) -> Int {
        if deal.status == .pendingReview { return 0 }
        if deal.isPartiallyEarned        { return 1 }
        return 2  // plain .claimed
    }

    /// Observe BrandCashbackService.$lastEarnedDeal via Combine to show overlay.
    private func observeServiceChanges() {
        service.$lastEarnedDeal
            .receive(on: RunLoop.main)
            .sink { [weak self] earned in
                guard let self, let earned else { return }
                self.lastEarnedAmount = earned.earned
                self.lastEarnedDealName = earned.deal.productName
                self.lastEarnedImageUrl = earned.deal.imageUrl
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
    /// (Backend brand-cashback matching runs in the receipt worker at ~2s post-OCR.)
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

    /// Surface a transient toast when the backend service detects a previously
    /// pending review has been denied (admin reviewed the receipt and rejected).
    private func observeDenialNotification() {
        denialObserver = NotificationCenter.default.addObserver(
            forName: .brandCashbackDenied,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let brand = notification.userInfo?["brandName"] as? String,
                  let product = notification.userInfo?["productName"] as? String,
                  let reason = notification.userInfo?["reason"] as? String else { return }
            Task { @MainActor in
                self.deniedToast = DeniedToast(
                    brandName: brand, productName: product, reason: reason
                )
            }
        }
    }

    /// On app foreground, re-poll deals so admin approvals/denials that
    /// happened while the app was in the background show up. The polling
    /// flow inside the service handles diffing and notifications.
    private func observeForeground() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.service.refreshAndDetectEarnings(receiptId: "")
            }
        }
    }
}

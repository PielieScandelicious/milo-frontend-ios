//
//  BrandCashbackWalletViewModel.swift
//  Scandalicious
//
//  Drives BrandCashbackWalletView. Loads /brand-cashback/wallet plus the
//  withdrawal info+history, refreshes on receipt-uploaded events, and exposes
//  a request-withdrawal action. Stays focused on read-side state — the actual
//  WithdrawalAPIService call happens in the request sheet's view layer.
//

import Foundation
import Combine
import UIKit

@MainActor
final class BrandCashbackWalletViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var wallet: BrandCashbackWallet = .empty
    @Published private(set) var withdrawalInfo: WithdrawalInfoResponse? = nil
    @Published private(set) var withdrawalHistory: [WithdrawalItemResponse] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private var receiptObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        observeReceiptUploads()
        observeForeground()
    }

    deinit {
        for observer in [receiptObserver, foregroundObserver] {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    // MARK: - Public

    /// Load all three (wallet + withdrawal info + history) in parallel.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let walletTask = loadWallet()
        async let infoTask = loadWithdrawalInfo()
        async let historyTask = loadWithdrawalHistory()
        _ = await (walletTask, infoTask, historyTask)
    }

    /// Refresh after a successful withdrawal so the new pending row + decremented
    /// balance show up immediately.
    func refreshAfterWithdrawal() async {
        await load()
    }

    // MARK: - Private loaders

    private func loadWallet() async {
        do {
            let fetched = try await BrandCashbackWalletService.shared.getWallet()
            self.wallet = fetched
        } catch {
            // Swallow — non-critical UI; surface only via global error if all three fail.
        }
    }

    private func loadWithdrawalInfo() async {
        do {
            self.withdrawalInfo = try await WithdrawalAPIService.shared.getInfo()
        } catch {
            // Same as above.
        }
    }

    private func loadWithdrawalHistory() async {
        do {
            let response = try await WithdrawalAPIService.shared.getHistory()
            self.withdrawalHistory = response.withdrawals
        } catch {
            // Same as above.
        }
    }

    // MARK: - Observers

    /// 3 s after a receipt finishes processing, refresh the wallet so any
    /// brand-cashback earning that just landed shows up. Mirrors the delay
    /// used by BrandCashbackViewModel.
    private func observeReceiptUploads() {
        receiptObserver = NotificationCenter.default.addObserver(
            forName: .receiptUploadedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                await self?.loadWallet()
            }
        }
    }

    /// On foreground, re-poll so admin approvals/denials made while we were
    /// backgrounded show up.
    private func observeForeground() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.load()
            }
        }
    }
}

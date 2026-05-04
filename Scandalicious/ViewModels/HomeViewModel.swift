//
//  HomeViewModel.swift
//  Scandalicious
//
//  Backs HomeTabView. Holds the recent uploaded receipts and listens for
//  receipt-completion events to refresh the list. All gamification state
//  (cashback reveal, points, spins, streaks) was removed when the app
//  collapsed to brand-cashback-only — the wallet lives in the Cashback tab now.
//

import SwiftUI

@Observable
class HomeViewModel {
    // Recent uploaded receipts list (from /receipts endpoint)
    var uploadedReceipts: [APIReceipt] = []
    var isLoadingReceipts: Bool = false

    private var completionObserver: Any?

    init() {
        // Seed from prefetched cache if available, otherwise lazy-load.
        let cache = BudgetTabPreloadCache.shared
        if cache.hasPreloaded, !cache.recentUploadedReceipts.isEmpty {
            self.uploadedReceipts = cache.recentUploadedReceipts
        } else {
            loadUploadedReceipts()
        }

        observeReceiptCompletion()
    }

    deinit {
        if let observer = completionObserver {
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

    // MARK: - Receipt Completion Observer

    /// Refresh the uploaded list when a receipt finishes, then auto-dismiss
    /// the processing card after 2 s. Brand cashback earnings flow through
    /// BrandCashbackViewModel + BrandCashbackWalletViewModel; this VM only
    /// cares about the receipts list.
    private func observeReceiptCompletion() {
        completionObserver = NotificationCenter.default.addObserver(
            forName: .receiptUploadedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let receiptId = notification.userInfo?["receiptId"] as? String
            Task { @MainActor in
                self.loadUploadedReceipts()
                try? await Task.sleep(for: .seconds(2))
                if let receiptId {
                    ReceiptProcessingManager.shared.dismiss(receiptId)
                }
            }
        }
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

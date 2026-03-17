//
//  PromosViewModel.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PromosViewModel: ObservableObject {
    @Published var state: LoadingState<PromoRecommendationResponse> = .idle

    private let apiService = PromoAPIService.shared
    private var isLoading = false
    private var viewedReportIDs: Set<String> = []
    private var openedDealKeys: Set<String> = []
    private var openedStoreKeys: Set<String> = []

    // MARK: - Load

    func loadPromos(forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh {
            return
        }

        if forceRefresh || {
            if case .idle = state { return true }
            if case .error = state { return true }
            return false
        }() {
            state = .loading
        }

        isLoading = true
        defer { isLoading = false }

        print("[PromosVM] fetching from API")
        do {
            let response = try await apiService.getRecommendations()
            state = .success(response)
            trackReportViewedIfNeeded(response)
            print("[PromosVM] success: status=\(response.reportStatus.rawValue), deals=\(response.dealCount)")
        } catch is CancellationError {
            print("[PromosVM] fetch cancelled, keeping current state")
        } catch {
            guard !Task.isCancelled else {
                print("[PromosVM] fetch cancelled (URLError), keeping current state")
                return
            }
            if case .success = state {
                print("[PromosVM] API failed, keeping current state: \(error.localizedDescription)")
            } else {
                state = .error(error.localizedDescription)
                print("[PromosVM] error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Event Tracking

    func trackReportViewedIfNeeded(_ response: PromoRecommendationResponse) {
        guard response.isReady, let reportID = response.reportId else { return }
        guard viewedReportIDs.insert(reportID).inserted else { return }
        Task {
            await apiService.logEvent(reportId: reportID, eventType: .reportViewed)
        }
    }

    func trackTopPickOpened(_ pick: PromoTopPick) {
        guard let report = readyReport, let reportID = report.reportId else { return }
        let itemKey = pick.itemKey ?? Self.syntheticItemKey(
            productName: pick.productName,
            storeName: pick.store,
            mechanism: pick.mechanism,
            validityStart: pick.validityStart,
            validityEnd: pick.validityEnd
        )
        guard openedDealKeys.insert(itemKey).inserted else { return }
        Task {
            await apiService.logEvent(
                reportId: reportID,
                eventType: .dealOpened,
                itemKey: itemKey,
                storeName: pick.store,
                metadata: ["surface": "top_pick"]
            )
        }
    }

    func trackStoreSectionOpened(_ store: PromoStore) {
        guard let report = readyReport, let reportID = report.reportId else { return }
        let storeKey = "\(reportID)|\(store.storeName)"
        guard openedStoreKeys.insert(storeKey).inserted else { return }
        Task {
            await apiService.logEvent(
                reportId: reportID,
                eventType: .storeSectionOpened,
                storeName: store.storeName
            )
        }
    }

    func trackFolderOpened(for pick: PromoTopPick) {
        guard let report = readyReport, let reportID = report.reportId else { return }
        let itemKey = pick.itemKey ?? Self.syntheticItemKey(
            productName: pick.productName,
            storeName: pick.store,
            mechanism: pick.mechanism,
            validityStart: pick.validityStart,
            validityEnd: pick.validityEnd
        )
        Task {
            await apiService.logEvent(
                reportId: reportID,
                eventType: .folderOpened,
                itemKey: itemKey,
                storeName: pick.store,
                metadata: ["surface": "top_pick"]
            )
        }
    }

    // MARK: - Convenience for banner

    var weeklySavings: Double { state.value?.weeklySavings ?? 0 }
    var dealCount: Int { state.value?.dealCount ?? 0 }
    var storeCount: Int { state.value?.stores.count ?? 0 }
    var hasData: Bool {
        guard let value = state.value else { return false }
        return value.isReady && value.dealCount > 0
    }

    private var readyReport: PromoRecommendationResponse? {
        guard case .success(let response) = state, response.isReady else { return nil }
        return response
    }

    private static func syntheticItemKey(
        productName: String,
        storeName: String,
        mechanism: String,
        validityStart: String,
        validityEnd: String
    ) -> String {
        [
            productName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            storeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            mechanism.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            validityStart,
            validityEnd
        ].joined(separator: "|")
    }
}

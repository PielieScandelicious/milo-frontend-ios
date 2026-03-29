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
    @Published var stores: [PromoStore] = []
    /// Ordered list of selected store names — source of truth for the manage sheet
    @Published var selectedStoreNames: [String] = []
    /// All stores that have deals this week (even if not selected), keyed by name
    private var allAvailableStores: [String: PromoStore] = [:]

    private let apiService = PromoAPIService.shared
    private let profileService = ProfileAPIService()
    private var isLoading = false
    private var lastGeneratedAt: String?
    private var viewedReportIDs: Set<String> = []
    private var openedStoreKeys: Set<String> = []

    // MARK: - Load

    func loadPromos(forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh {
            return
        }

        let alreadyHasData: Bool = { if case .success = state { return true }; return false }()

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

            if !forceRefresh && alreadyHasData && response.generatedAt == lastGeneratedAt {
                print("[PromosVM] data unchanged (generated_at=\(lastGeneratedAt ?? "nil")), refreshing state for date recalc")
                state = .success(response)
                populateStoreData(from: response)
                return
            }

            state = .success(response)
            populateStoreData(from: response)
            lastGeneratedAt = response.generatedAt
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

    func trackDealClaimed(item: PromoStoreItem, store: PromoStore, reportId: String?) {
        guard let reportID = reportId else { return }
        Task {
            await apiService.logEvent(
                reportId: reportID,
                eventType: .dealClaimed,
                itemKey: item.itemKey,
                storeName: store.storeName
            )
        }
    }

    // MARK: - Manage Stores (select, deselect, reorder)

    /// Stores available to add (have deals this week but are not selected)
    var availableStores: [GroceryStore] {
        let selectedSet = Set(selectedStoreNames)
        return GroceryStore.promoSupported.filter { !selectedSet.contains($0.canonicalName) }
    }

    /// Deal count for a store name (from this week's data)
    func dealCount(for storeName: String) -> Int {
        allAvailableStores[storeName]?.items.count ?? 0
    }

    func moveStore(from source: IndexSet, to destination: Int) {
        selectedStoreNames.move(fromOffsets: source, toOffset: destination)
        rebuildDisplayStores()
    }

    func addStore(_ store: GroceryStore) {
        guard !selectedStoreNames.contains(store.canonicalName) else { return }
        selectedStoreNames.append(store.canonicalName)
        rebuildDisplayStores()
    }

    func removeStore(at offsets: IndexSet) {
        selectedStoreNames.remove(atOffsets: offsets)
        rebuildDisplayStores()
    }

    func removeStore(named name: String) {
        selectedStoreNames.removeAll { $0 == name }
        rebuildDisplayStores()
    }

    /// Persist selection + order to backend and reload promos
    func saveStorePreferences() {
        Task {
            do {
                _ = try await profileService.updateProfile(
                    nickname: nil, gender: nil, age: nil,
                    language: nil, preferredStores: selectedStoreNames
                )
                print("[PromosVM] store preferences saved: \(selectedStoreNames)")
                await loadPromos(forceRefresh: true)
            } catch {
                print("[PromosVM] failed to save store preferences: \(error.localizedDescription)")
            }
        }
    }

    private func rebuildDisplayStores() {
        stores = selectedStoreNames.map { name in
            allAvailableStores[name] ?? PromoStore(
                storeName: name, totalSavings: 0, validityEnd: "", items: []
            )
        }
    }

    private func populateStoreData(from response: PromoRecommendationResponse) {
        // Build lookup of all stores with deals
        for store in response.stores {
            allAvailableStores[store.storeName] = store
        }

        // Determine selected stores:
        // 1. Use API preferred_stores if available (includes stores with no deals)
        // 2. Keep local selectedStoreNames if already populated (user just saved preferences)
        // 3. Fall back to stores with deals on truly fresh load
        if let preferred = response.preferredStores, !preferred.isEmpty {
            selectedStoreNames = preferred
        } else if selectedStoreNames.isEmpty {
            selectedStoreNames = response.stores.map(\.storeName)
        }
        // else: keep existing selectedStoreNames (preserves user's selection through reload)

        rebuildDisplayStores()
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

}

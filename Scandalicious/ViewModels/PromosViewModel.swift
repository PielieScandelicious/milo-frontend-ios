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

    /// True while reloading after store selection change — shows dachshund instead of stale empty state
    @Published var isReloadingAfterStoreChange = false

    private let apiService = PromoAPIService.shared
    private let profileService = ProfileAPIService()
    private var isLoading = false
    private var lastGeneratedAt: String?
    private var viewedReportIDs: Set<String> = []
    private var openedStoreKeys: Set<String> = []
    /// Snapshot of selectedStoreNames when the manage sheet opens, for dirty checking
    private var storeNamesBeforeManage: [String] = []

    // MARK: - Load

    func loadPromos(forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh {
            return
        }

        let alreadyHasData: Bool = { if case .success = state { return true }; return false }()

        // On first load, try to use prefetched data from app startup
        if !forceRefresh && !alreadyHasData {
            let cache = BudgetTabPreloadCache.shared
            if let prefetched = cache.promoData {
                state = .success(prefetched)
                populateStoreData(from: prefetched)
                lastGeneratedAt = prefetched.generatedAt
                trackReportViewedIfNeeded(prefetched)
                print("[PromosVM] loaded from prefetch cache")
                return
            }
        }

        if !alreadyHasData && (forceRefresh || {
            if case .idle = state { return true }
            if case .error = state { return true }
            return false
        }()) {
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
            if case .loading = state { state = .idle }
            print("[PromosVM] fetch cancelled, restoring to idle if no data")
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
        // First check full store data (selected stores with items)
        if let count = allAvailableStores[storeName]?.items.count, count > 0 {
            return count
        }
        // Fall back to summary breakdown (covers ALL stores including unselected)
        if let breakdown = state.value?.summary.storesBreakdown.first(where: { $0.store == storeName }) {
            return breakdown.items
        }
        return 0
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

    /// Call when the manage sheet opens to snapshot current state
    func beginManagingStores() {
        storeNamesBeforeManage = selectedStoreNames
    }

    /// Persist selection + order to backend and reload promos (only if stores added/removed)
    func saveStorePreferences() {
        let selectionChanged = Set(selectedStoreNames) != Set(storeNamesBeforeManage)
        let orderChanged = selectedStoreNames != storeNamesBeforeManage

        // Reorder only — update display locally, persist in background, no reload
        if !selectionChanged && orderChanged {
            rebuildDisplayStores()
            Task {
                do {
                    _ = try await profileService.updateProfile(
                        nickname: nil, gender: nil, age: nil,
                        language: nil, preferredStores: selectedStoreNames
                    )
                    print("[PromosVM] store order saved: \(selectedStoreNames)")
                } catch {
                    print("[PromosVM] failed to save store order: \(error.localizedDescription)")
                }
            }
            return
        }

        guard selectionChanged else { return }
        isReloadingAfterStoreChange = true
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
            isReloadingAfterStoreChange = false
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
        // 1. Use API preferred_stores if returned (even if empty — user explicitly cleared them)
        // 2. Keep local selectedStoreNames if already populated (user just saved preferences)
        // 3. Fall back to stores with deals on truly fresh load (preferredStores is nil)
        if let preferred = response.preferredStores {
            selectedStoreNames = preferred
        } else if selectedStoreNames.isEmpty {
            selectedStoreNames = response.stores.map(\.storeName)
        }

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

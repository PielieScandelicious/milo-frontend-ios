//
//  PromoSearchViewModel.swift
//  Scandalicious
//
//  Orchestrates the Folders-tab search bar: state machine, debounced query,
//  cache hits, and telemetry. Drives FolderSearchOverlay.
//

import Foundation
import Combine

@MainActor
final class PromoSearchViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle           // bar not focused
        case empty          // focused, no query — show recent + popular brands
        case tooShort       // focused, 1-char query — show "type at least 2 characters"
        case loading        // request pending
        case results        // results array populated
        case noResults      // request returned 0 items
        case error(String)
    }

    @Published var query: String = ""
    @Published var isFocused: Bool = false
    @Published var storeFilters: Set<String> = PromoSearchViewModel.loadPersistedStoreFilters() {
        didSet {
            UserDefaults.standard.set(
                Array(storeFilters).sorted(),
                forKey: PromoSearchViewModel.storeFiltersKey
            )
        }
    }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var results: [PromoStoreItem] = []
    @Published private(set) var matchedCategories: [String] = []
    @Published private(set) var popularBrands: [PopularBrand] = []

    private static let minQueryLength = 2
    private static let debounceMs: UInt64 = 300_000_000
    private static let resultLimit = 20
    private static let storeFiltersKey = "promo_search_store_filters_v1"

    private static func loadPersistedStoreFilters() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storeFiltersKey) ?? [])
    }

    private var searchTask: Task<Void, Never>?
    private var lastSubmittedTelemetryQuery: String = ""

    /// Called by the view when the focus state changes.
    func setFocused(_ focused: Bool) {
        isFocused = focused
        recomputePhase()
        if focused, popularBrands.isEmpty {
            Task { await loadPopularBrandsIfNeeded() }
        }
    }

    /// Called by the view's `.onChange(of: query)` (or `.task(id:)`) to drive search.
    func onQueryChange() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            results = []
            matchedCategories = []
            recomputePhase()
            return
        }

        if trimmed.count < Self.minQueryLength {
            results = []
            matchedCategories = []
            phase = .tooShort
            return
        }

        // Cache peek — show cached results instantly without flashing a spinner.
        let storesArray = Array(storeFilters)
        if let cached = PromoSearchCache.shared.cached(
            query: trimmed, stores: storesArray, limit: Self.resultLimit
        ) {
            applyResponse(cached)
            return
        }

        phase = .loading
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceMs)
            guard let self else { return }
            if Task.isCancelled { return }
            await self.performSearch(query: trimmed, stores: Array(self.storeFilters))
        }
    }

    /// Toggle a single store in the multi-select filter. Re-runs the search.
    func toggleStoreFilter(_ store: String) {
        if storeFilters.contains(store) {
            storeFilters.remove(store)
        } else {
            storeFilters.insert(store)
        }
        onQueryChange()
    }

    /// Clear all store filters (the "all stores" affordance). Re-runs the search.
    func clearStoreFilters() {
        guard !storeFilters.isEmpty else { return }
        storeFilters.removeAll()
        onQueryChange()
    }

    /// Called when the user taps a recent search or popular brand chip.
    func submitSuggestedQuery(_ value: String) {
        query = value
        onQueryChange()
    }

    func clearQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= Self.minQueryLength, !results.isEmpty {
            RecentSearchesManager.shared.add(trimmed)
        }
        query = ""
        results = []
        matchedCategories = []
        recomputePhase()
    }

    /// Called by the suggestion row right before opening the detail sheet.
    /// Persists the query, fires telemetry. Caller still presents the sheet.
    func recordResultTap(_ item: PromoStoreItem, position: Int) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            RecentSearchesManager.shared.add(trimmed)
        }
        Task {
            await PromoAPIService.shared.logInteractionEvent(
                eventType: .searchResultTapped,
                promoItemId: item.itemKey,
                storeName: item.storeName,
                metadata: [
                    "q": trimmed,
                    "position": String(position),
                    "store_filter": Array(storeFilters).sorted().joined(separator: ","),
                ]
            )
        }
    }

    // MARK: - Private

    private func performSearch(query: String, stores: [String]) async {
        let response = await PromoSearchCache.shared.getOrFetch(
            query: query, stores: stores, limit: Self.resultLimit
        )
        if Task.isCancelled { return }

        guard let response else {
            // Underlying call swallowed the error; surface a generic one.
            phase = .error(L("unknown_error"))
            return
        }

        applyResponse(response)
        await maybeLogQueryTelemetry(query: query, stores: stores, response: response)
    }

    private func applyResponse(_ response: PromoSearchResponse) {
        results = response.items
        matchedCategories = response.matchedCategories
        phase = response.items.isEmpty ? .noResults : .results
    }

    private func recomputePhase() {
        if !isFocused {
            phase = .idle
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            phase = .empty
        } else if trimmed.count < Self.minQueryLength {
            phase = .tooShort
        }
        // .loading / .results / .noResults / .error are owned by the search task.
    }

    private func loadPopularBrandsIfNeeded() async {
        do {
            let brands = try await PromoAPIService.shared.getPopularBrands(limit: 10)
            self.popularBrands = brands
        } catch {
            // Silent — empty state just won't show the chip strip.
        }
    }

    /// Single dwell-debounced telemetry fire per query, so we don't log every keystroke.
    private func maybeLogQueryTelemetry(
        query: String, stores: [String], response: PromoSearchResponse
    ) async {
        let storesKey = stores.sorted().joined(separator: ",")
        let key = "\(query.lowercased())|\(storesKey)"
        guard key != lastSubmittedTelemetryQuery else { return }
        lastSubmittedTelemetryQuery = key
        await PromoAPIService.shared.logInteractionEvent(
            eventType: .searchQuerySubmitted,
            metadata: [
                "q": query,
                "store_filter": storesKey,
                "result_count": String(response.items.count),
                "matched_categories": response.matchedCategories.joined(separator: ","),
            ]
        )
    }
}

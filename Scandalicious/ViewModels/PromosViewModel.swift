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
    private var lastFetchDate: Date?
    private var cachedResponse: PromoRecommendationResponse?
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutes

    func loadPromos(forceRefresh: Bool = false) async {
        print("[PromosVM] loadPromos called, forceRefresh=\(forceRefresh)")

        // Use cache if recent enough
        if !forceRefresh,
           let cached = cachedResponse,
           let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < cacheValiditySeconds {
            if case .success = state { return }
            state = .success(cached)
            return
        }

        state = .loading
        print("[PromosVM] state -> loading, calling API...")

        do {
            let response = try await apiService.getRecommendations()
            cachedResponse = response
            lastFetchDate = Date()
            state = .success(response)
            print("[PromosVM] success: \(response.dealCount) deals, €\(response.weeklySavings) savings")
        } catch {
            state = .error(error.localizedDescription)
            print("[PromosVM] error: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        await loadPromos(forceRefresh: true)
    }

    // MARK: - Convenience for banner

    var weeklySavings: Double { state.value?.weeklySavings ?? 0 }
    var dealCount: Int { state.value?.dealCount ?? 0 }
    var storeCount: Int { state.value?.stores.count ?? 0 }
    var hasData: Bool { state.value != nil && (state.value?.dealCount ?? 0) > 0 }
}

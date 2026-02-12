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
    @Published var isRefreshing = false

    private let apiService = PromoAPIService.shared

    // MARK: - Load (always fresh — no caching, dachshund sniffs every time)

    func loadPromos(forceRefresh: Bool = false) async {
        // If we already have data and not forcing refresh, skip re-fetch
        if case .success = state, !forceRefresh {
            print("[PromosVM] loadPromos skipped — data already loaded")
            return
        }

        print("[PromosVM] loadPromos called — fetching fresh")
        state = .loading

        do {
            let response = try await apiService.getRecommendations()
            state = .success(response)
            print("[PromosVM] success: \(response.dealCount) deals, €\(response.weeklySavings) savings")
        } catch {
            state = .error(error.localizedDescription)
            print("[PromosVM] error: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        isRefreshing = true
        // During pull-to-refresh, keep current data visible
        do {
            let response = try await apiService.getRecommendations()
            state = .success(response)
            print("[PromosVM] refresh success: \(response.dealCount) deals")
        } catch {
            if case .success = state {
                print("[PromosVM] refresh failed, keeping current data: \(error.localizedDescription)")
            } else {
                state = .error(error.localizedDescription)
            }
            print("[PromosVM] refresh error: \(error.localizedDescription)")
        }
        isRefreshing = false
    }

    // MARK: - Convenience for banner

    var weeklySavings: Double { state.value?.weeklySavings ?? 0 }
    var dealCount: Int { state.value?.dealCount ?? 0 }
    var storeCount: Int { state.value?.stores.count ?? 0 }
    var hasData: Bool { state.value != nil && (state.value?.dealCount ?? 0) > 0 }
}

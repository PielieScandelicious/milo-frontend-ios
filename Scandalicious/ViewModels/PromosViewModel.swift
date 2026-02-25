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
    private var hasFetchedThisSession = false

    // MARK: - Cache

    private static var cacheFileURL: URL {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("promos_cache.json")
        }
        return caches.appendingPathComponent("promos_cache.json")
    }

    private func saveToCache(_ response: PromoRecommendationResponse) {
        do {
            let data = try JSONEncoder().encode(response)
            try data.write(to: Self.cacheFileURL)
            print("[PromosVM] cached to disk")
        } catch {
            print("[PromosVM] cache write failed: \(error.localizedDescription)")
        }
    }

    private func loadFromCache() -> PromoRecommendationResponse? {
        guard let data = try? Data(contentsOf: Self.cacheFileURL),
              let response = try? JSONDecoder().decode(PromoRecommendationResponse.self, from: data) else {
            return nil
        }
        print("[PromosVM] loaded from disk cache")
        return response
    }

    // MARK: - Load (once per app launch, then cached)

    func loadPromos() async {
        // Already have data this session — skip
        if case .success = state {
            print("[PromosVM] loadPromos skipped — data already loaded")
            return
        }

        // Show cached data immediately while fetching
        if let cached = loadFromCache() {
            state = .success(cached)
        }

        // Only fetch from API once per app session (allow retry on error)
        if hasFetchedThisSession, case .success = state { return }
        hasFetchedThisSession = true

        // If no cache yet, show loading state
        if case .idle = state {
            state = .loading
        } else if case .error = state {
            state = .loading
        }

        print("[PromosVM] fetching from API")
        do {
            let response = try await apiService.getRecommendations()
            state = .success(response)
            saveToCache(response)
            print("[PromosVM] success: \(response.dealCount) deals, €\(response.weeklySavings) savings")
        } catch is CancellationError {
            // Task was cancelled (e.g. user navigated back) — keep current state
            print("[PromosVM] fetch cancelled, keeping current state")
            hasFetchedThisSession = false
        } catch {
            guard !Task.isCancelled else {
                // URLSession wraps cancellation in URLError — keep current state
                print("[PromosVM] fetch cancelled (URLError), keeping current state")
                hasFetchedThisSession = false
                return
            }
            // If we already have cached data, keep showing it
            if case .success = state {
                print("[PromosVM] API failed, keeping cached data: \(error.localizedDescription)")
            } else {
                state = .error(error.localizedDescription)
                print("[PromosVM] error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Convenience for banner

    var weeklySavings: Double { state.value?.weeklySavings ?? 0 }
    var dealCount: Int { state.value?.dealCount ?? 0 }
    var storeCount: Int { state.value?.stores.count ?? 0 }
    var hasData: Bool { state.value != nil && (state.value?.dealCount ?? 0) > 0 }
}

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

    // Auto-refetch every 3.5 days (twice a week)
    private let autoRefetchInterval: TimeInterval = 3.5 * 24 * 60 * 60

    // MARK: - Disk Cache

    private static let cacheFileName = "promos_cache.json"
    private static let lastFetchKey = "promos_last_fetch_date"

    private static var cacheFileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent(cacheFileName)
    }

    private var lastFetchDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastFetchKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastFetchKey) }
    }

    // MARK: - Load

    func loadPromos(forceRefresh: Bool = false) async {
        print("[PromosVM] loadPromos called, forceRefresh=\(forceRefresh)")

        // Try disk cache first (unless force refresh)
        if !forceRefresh, let cached = loadFromDisk() {
            let lastFetch = lastFetchDate ?? .distantPast
            let age = Date().timeIntervalSince(lastFetch)

            // Serve cached data immediately
            if case .success = state {} else {
                state = .success(cached)
            }

            // If cache is still fresh (< 3.5 days), don't refetch
            if age < autoRefetchInterval {
                print("[PromosVM] serving disk cache, age: \(String(format: "%.1f", age / 3600))h")
                return
            }

            // Cache is stale — refetch in background (user still sees cached data)
            print("[PromosVM] cache stale (\(String(format: "%.1f", age / 3600))h), refetching...")
        }

        // Show loading only if we have no cached data to display
        if case .success = state {} else {
            state = .loading
        }
        print("[PromosVM] calling API...")

        do {
            let response = try await apiService.getRecommendations()
            saveToDisk(response)
            lastFetchDate = Date()
            state = .success(response)
            print("[PromosVM] success: \(response.dealCount) deals, €\(response.weeklySavings) savings")
        } catch {
            // Only show error if we have no cached data
            if case .success = state {
                print("[PromosVM] refresh failed but showing cached data: \(error.localizedDescription)")
            } else {
                state = .error(error.localizedDescription)
            }
            print("[PromosVM] error: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        isRefreshing = true
        await loadPromos(forceRefresh: true)
        isRefreshing = false
    }

    // MARK: - Disk Persistence

    private func saveToDisk(_ response: PromoRecommendationResponse) {
        do {
            let data = try JSONEncoder().encode(response)
            try data.write(to: Self.cacheFileURL, options: .atomic)
            print("[PromosVM] saved cache to disk (\(data.count) bytes)")
        } catch {
            print("[PromosVM] failed to save cache: \(error)")
        }
    }

    private func loadFromDisk() -> PromoRecommendationResponse? {
        guard FileManager.default.fileExists(atPath: Self.cacheFileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: Self.cacheFileURL)
            let response = try JSONDecoder().decode(PromoRecommendationResponse.self, from: data)
            print("[PromosVM] loaded cache from disk (\(response.dealCount) deals)")
            return response
        } catch {
            print("[PromosVM] failed to load cache: \(error)")
            return nil
        }
    }

    // MARK: - Convenience for banner

    var weeklySavings: Double { state.value?.weeklySavings ?? 0 }
    var dealCount: Int { state.value?.dealCount ?? 0 }
    var storeCount: Int { state.value?.stores.count ?? 0 }
    var hasData: Bool { state.value != nil && (state.value?.dealCount ?? 0) > 0 }
}

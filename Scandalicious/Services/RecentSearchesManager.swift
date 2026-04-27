//
//  RecentSearchesManager.swift
//  Scandalicious
//
//  Persists the user's last ~10 promo search queries for the Folders search
//  bar's empty-focused state. Mirrors FavoriteStoresManager: @MainActor
//  singleton with @Published state, UserDefaults-backed via didSet.
//

import Foundation
import Combine

@MainActor
final class RecentSearchesManager: ObservableObject {
    static let shared = RecentSearchesManager()

    private static let storageKey = "promo_recent_searches_v1"
    private static let maxCount = 10

    @Published var searches: [String] {
        didSet {
            UserDefaults.standard.set(searches, forKey: Self.storageKey)
        }
    }

    private init() {
        self.searches = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
    }

    /// Insert at the head, deduping case-insensitively, capped at maxCount.
    func add(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let folded = query.lowercased()
        var next = searches.filter { $0.lowercased() != folded }
        next.insert(query, at: 0)
        if next.count > Self.maxCount {
            next = Array(next.prefix(Self.maxCount))
        }
        searches = next
    }

    func remove(_ query: String) {
        searches.removeAll { $0 == query }
    }

    func clear() {
        searches = []
    }
}

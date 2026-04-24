//
//  FavoriteStoresManager.swift
//  Scandalicious
//
//  Persists the user's favorite grocery stores for the Folders tab.
//  Stores canonical store IDs (lowercase strings) so new backend stores
//  work even if the iOS GroceryStore enum hasn't been updated yet.
//

import Foundation
import Combine

@MainActor
final class FavoriteStoresManager: ObservableObject {
    static let shared = FavoriteStoresManager()

    private static let storageKey = "favorite_stores_v1"

    @Published var favorites: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(favorites), forKey: Self.storageKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        self.favorites = Set(stored)
    }

    func contains(_ storeId: String) -> Bool {
        favorites.contains(storeId)
    }

    func toggle(_ storeId: String) {
        if favorites.contains(storeId) {
            favorites.remove(storeId)
        } else {
            favorites.insert(storeId)
        }
    }

    func setAll(_ storeIds: [String]) {
        favorites = Set(storeIds)
    }

    func clear() {
        favorites = []
    }
}

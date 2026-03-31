//
//  GroceryListStore.swift
//  Scandalicious
//

import Foundation
import Combine

@MainActor
class GroceryListStore: ObservableObject {
    static let shared = GroceryListStore()

    @Published private(set) var items: [GroceryListItem] = []

    private let storageKey = "grocery_list_items_v1"

    private init() {
        loadFromDisk()
        removeExpired()
    }

    // MARK: - Public API

    func add(item: PromoStoreItem, storeName: String) {
        guard !contains(item: item, storeName: storeName) else { return }
        let groceryItem = GroceryListItem.from(item: item, storeName: storeName)
        items.append(groceryItem)
        saveToDisk()
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        saveToDisk()
    }

    func removeByPromo(item: PromoStoreItem, storeName: String) {
        items.removeAll { $0.brand == item.brand && $0.productName == item.productName && $0.storeName == storeName }
        saveToDisk()
    }

    func toggleChecked(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isChecked.toggle()
        saveToDisk()
    }

    func removeChecked() {
        items.removeAll { $0.isChecked }
        saveToDisk()
    }

    func removeAll() {
        items.removeAll()
        saveToDisk()
    }

    func removeExpired() {
        let before = items.count
        items.removeAll { $0.isExpired }
        if items.count != before {
            saveToDisk()
        }
    }

    func contains(item: PromoStoreItem, storeName: String) -> Bool {
        items.contains { $0.brand == item.brand && $0.productName == item.productName && $0.storeName == storeName && !$0.isExpired }
    }

    // MARK: - Computed

    var activeItems: [GroceryListItem] {
        items.filter { !$0.isExpired }
    }

    var activeItemCount: Int {
        activeItems.count
    }

    var uncheckedCount: Int {
        activeItems.filter { !$0.isChecked }.count
    }

    var totalSavings: Double {
        activeItems.reduce(0) { $0 + $1.savings }
    }

    var itemsByStore: [(storeName: String, items: [GroceryListItem])] {
        let grouped = Dictionary(grouping: activeItems, by: \.storeName)
        return grouped
            .sorted { $0.key < $1.key }
            .map { (storeName: $0.key, items: $0.value) }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([GroceryListItem].self, from: data)
        else { return }
        items = decoded
    }
}

//
//  GroceryListStore.swift
//  Scandalicious
//

import Foundation
import Combine

@MainActor
class GroceryListStore: ObservableObject {
    static let shared = GroceryListStore()

    @Published private(set) var items: [GroceryListItem] = [] {
        didSet { refreshMembership() }
    }

    /// O(1) membership index. Keyed on `"\(brand)|\(productName)|\(storeName)"`
    /// over non-expired items. Rebuilt whenever `items` changes, so callers can
    /// check membership in constant time instead of scanning the array — matters
    /// when 20 search rows each ask `contains(...)` on every render.
    private var membershipKeys: Set<String> = []

    /// Fires whenever a new item is successfully added. Used to trigger UI feedback (e.g. tab-bar toast).
    let itemAddedPublisher = PassthroughSubject<GroceryListItem, Never>()

    private let storageKey = "grocery_list_items_v1"

    private init() {
        loadFromDisk()
        removeExpired()

        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.removeExpired() }
        }
    }

    // MARK: - Public API

    func add(item: PromoStoreItem, storeName: String, validityEndOverride: String? = nil) {
        guard !contains(item: item, storeName: storeName) else { return }
        let groceryItem = GroceryListItem.from(item: item, storeName: storeName, validityEndOverride: validityEndOverride)
        items.append(groceryItem)
        saveToDisk()
        ImagePrefetcher.shared.prefetch(urlString: groceryItem.imageUrl)
        itemAddedPublisher.send(groceryItem)
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
        membershipKeys.contains(
            Self.membershipKey(brand: item.brand, productName: item.productName, storeName: storeName)
        )
    }

    private static func membershipKey(brand: String, productName: String, storeName: String) -> String {
        "\(brand)|\(productName)|\(storeName)"
    }

    private func refreshMembership() {
        membershipKeys = Set(items.lazy.filter { !$0.isExpired }.map {
            Self.membershipKey(brand: $0.brand, productName: $0.productName, storeName: $0.storeName)
        })
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
            .map { (storeName: $0.key, items: $0.value.sorted { a, b in
                let dA = a.daysRemaining ?? Int.max
                let dB = b.daysRemaining ?? Int.max
                if dA != dB { return dA < dB }
                return a.savings > b.savings
            }) }
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

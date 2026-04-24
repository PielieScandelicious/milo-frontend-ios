//
//  PromoFoldersViewModel.swift
//  Scandalicious
//
//  ViewModel for browsable promo folder pages.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PromoFoldersViewModel: ObservableObject {
    @Published var state: LoadingState<[PromoFolder]> = .idle
    @Published var selectedStoreFilter: String? = nil

    private let apiService = PromoAPIService.shared
    private var isLoading = false

    // MARK: - Grouped data

    /// Unique store IDs from loaded folders, preserving sort order
    var storeIds: [String] {
        guard case .success(let folders) = state else { return [] }
        var seen = Set<String>()
        return folders.compactMap { folder in
            guard seen.insert(folder.storeId).inserted else { return nil }
            return folder.storeId
        }
    }

    /// Store filter options: (storeId, displayName, folderCount)
    var storeFilterOptions: [(storeId: String, displayName: String, count: Int)] {
        guard case .success(let folders) = state else { return [] }
        var counts: [String: (String, Int)] = [:]
        for folder in folders {
            let existing = counts[folder.storeId]
            counts[folder.storeId] = (folder.storeDisplayName, (existing?.1 ?? 0) + 1)
        }
        return storeIds.compactMap { id in
            guard let (name, count) = counts[id] else { return nil }
            return (storeId: id, displayName: name, count: count)
        }
    }

    /// Folders filtered by the selected store (or all if no filter)
    var filteredFolders: [PromoFolder] {
        guard case .success(let folders) = state else { return [] }
        if let filter = selectedStoreFilter {
            return folders.filter { $0.storeId == filter }
        }
        return folders
    }

    /// Folders grouped by store for the browse view
    var foldersByStore: [(storeId: String, displayName: String, folders: [PromoFolder])] {
        let folders = filteredFolders
        var seen = Set<String>()
        var result: [(storeId: String, displayName: String, folders: [PromoFolder])] = []
        for folder in folders {
            if seen.insert(folder.storeId).inserted {
                let storeFolders = folders.filter { $0.storeId == folder.storeId }
                result.append((
                    storeId: folder.storeId,
                    displayName: folder.storeDisplayName,
                    folders: storeFolders
                ))
            }
        }
        return result
    }

    /// Split the grouped folders into favorite vs. other stores, dropping
    /// expired folders and stores that have no surviving folders. Favorites
    /// are ordered by how the user picked them relative to the API order —
    /// we preserve the API's store order within each partition so the layout
    /// stays stable between refreshes.
    func foldersByStorePartitioned(favorites: Set<String>)
        -> (favorites: [(storeId: String, displayName: String, folders: [PromoFolder])],
            others: [(storeId: String, displayName: String, folders: [PromoFolder])]) {
        let active = foldersByStore
            .map { (storeId: $0.storeId, displayName: $0.displayName, folders: $0.folders.filter { ($0.daysRemaining ?? 0) >= 0 }) }
            .filter { !$0.folders.isEmpty }

        var favs: [(storeId: String, displayName: String, folders: [PromoFolder])] = []
        var others: [(storeId: String, displayName: String, folders: [PromoFolder])] = []
        for group in active {
            if favorites.contains(group.storeId) {
                favs.append(group)
            } else {
                others.append(group)
            }
        }
        return (favs, others)
    }

    var totalFolderCount: Int {
        guard case .success(let folders) = state else { return 0 }
        return folders.count
    }

    // MARK: - Lookup

    /// Returns the folder + zero-based page index containing the given item, or nil.
    ///
    /// Match order (strongest first):
    ///   1. itemKey ↔ hotspot.itemId across *all* folders — item_ids are globally
    ///      unique, so a hit is authoritative even if storeName disagrees.
    ///   2. store + validity_end + pageNumber — disambiguates stores that publish
    ///      overlapping folders (e.g. weekly + themed) in the same week.
    ///   3. store + pageNumber — last-resort when validity is missing.
    func findFolder(for item: PromoStoreItem, storeName: String) -> (folder: PromoFolder, pageIndex: Int)? {
        guard case .success(let folders) = state else { return nil }

        // Phase 1 — authoritative itemKey match.
        if let key = item.itemKey {
            for folder in folders {
                if let idx = folder.pages.firstIndex(where: { $0.hotspots.contains { $0.itemId == key } }) {
                    return (folder, idx)
                }
            }
        }

        // Phase 2/3 — fall back to pageNumber within the item's store.
        guard let page = item.pageNumber else { return nil }
        let normalizedStore = storeName.lowercased()
        let candidates = folders.filter { $0.storeId.lowercased() == normalizedStore }

        if !item.validityEnd.isEmpty {
            for folder in candidates where folder.validityEnd == item.validityEnd {
                if let idx = folder.pages.firstIndex(where: { $0.pageNumber == page }) {
                    return (folder, idx)
                }
            }
        }

        for folder in candidates {
            if let idx = folder.pages.firstIndex(where: { $0.pageNumber == page }) {
                return (folder, idx)
            }
        }

        // A non-nil pageNumber that still didn't match likely means folders for
        // this store haven't loaded, or the promo outlived its source folder —
        // surface it so we can investigate instead of silently hiding the CTA.
        print("[PromoFoldersVM] findFolder miss — store=\(storeName) page=\(page) itemKey=\(item.itemKey ?? "nil") validityEnd=\(item.validityEnd)")
        return nil
    }

    // MARK: - Load

    func loadFolders(forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh { return }

        // Try prefetch cache first
        if !forceRefresh, case .idle = state {
            if let cached = BudgetTabPreloadCache.shared.promoFolders {
                state = .success(cached.folders)
                print("[PromoFoldersVM] loaded from prefetch cache (\(cached.folders.count) folders)")
                return
            }
        }

        let alreadyHasData: Bool = { if case .success = state { return true }; return false }()
        if !alreadyHasData {
            state = .loading
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apiService.getFolders()
            state = .success(response.folders)
            print("[PromoFoldersVM] loaded \(response.folders.count) folders from API")
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            guard !Task.isCancelled else { return }
            if case .success = state {
                print("[PromoFoldersVM] API failed, keeping current data: \(error.localizedDescription)")
            } else {
                state = .error(error.localizedDescription)
                print("[PromoFoldersVM] error: \(error.localizedDescription)")
            }
        }
    }
}

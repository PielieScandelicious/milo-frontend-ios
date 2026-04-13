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

    var totalFolderCount: Int {
        guard case .success(let folders) = state else { return 0 }
        return folders.count
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

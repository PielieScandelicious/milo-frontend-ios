//
//  ReadFoldersManager.swift
//  Scandalicious
//
//  Persists which promo folders the user has opened, so unread folders
//  can be surfaced with a NEW badge and opened folders can be visually
//  dimmed in the Folders tab.
//

import Foundation
import Combine

@MainActor
final class ReadFoldersManager: ObservableObject {
    static let shared = ReadFoldersManager()

    private static let storageKey = "read_folders_v1"

    @Published var readFolders: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(readFolders), forKey: Self.storageKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        self.readFolders = Set(stored)
    }

    func contains(_ folderId: String) -> Bool {
        readFolders.contains(folderId)
    }

    func markAsRead(_ folderId: String) {
        if !readFolders.contains(folderId) {
            readFolders.insert(folderId)
        }
    }
}

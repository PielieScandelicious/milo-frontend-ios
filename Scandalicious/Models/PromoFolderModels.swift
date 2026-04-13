//
//  PromoFolderModels.swift
//  Scandalicious
//
//  Models for browsable promo folder pages served from R2.
//

import Foundation

// MARK: - Folder Page

struct PromoFolderPage: Codable, Identifiable {
    let pageNumber: Int
    let imageUrl: String

    var id: Int { pageNumber }

    enum CodingKeys: String, CodingKey {
        case pageNumber = "page_number"
        case imageUrl = "image_url"
    }
}

// MARK: - Folder

struct PromoFolder: Codable, Identifiable {
    let folderId: String
    let storeId: String
    let storeDisplayName: String
    let folderName: String
    let sourceUrl: String
    let validityStart: String
    let validityEnd: String
    let pageCount: Int
    let pages: [PromoFolderPage]

    var id: String { folderId }

    /// First page image URL, used as cover thumbnail
    var coverImageUrl: String? { pages.first?.imageUrl }

    /// Formatted validity label, e.g. "Until 15/04"
    var validityLabel: String {
        let parts = validityEnd.split(separator: "-")
        guard parts.count == 3 else { return validityEnd }
        return "Until \(parts[2])/\(parts[1])"
    }

    enum CodingKeys: String, CodingKey {
        case folderId = "folder_id"
        case storeId = "store_id"
        case storeDisplayName = "store_display_name"
        case folderName = "folder_name"
        case sourceUrl = "source_url"
        case validityStart = "validity_start"
        case validityEnd = "validity_end"
        case pageCount = "page_count"
        case pages
    }
}

// MARK: - Response

struct PromoFoldersResponse: Codable {
    let folders: [PromoFolder]
}

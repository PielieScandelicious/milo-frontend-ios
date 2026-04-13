//
//  PromoFolderModels.swift
//  Scandalicious
//
//  Models for browsable promo folder pages served from R2.
//

import Foundation
import SwiftUI

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

    /// Days remaining until validity_end
    var daysRemaining: Int? {
        let parts = validityEnd.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let endDate = Calendar.current.date(from: components) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: endDate)
        return Calendar.current.dateComponents([.day], from: today, to: end).day
    }

    /// Validity display matching the Deals tab style: text + color + optional icon
    var validityDisplay: (text: String, color: Color, icon: String?) {
        guard let days = daysRemaining else {
            return (validityFallback, .white.opacity(0.4), nil)
        }
        switch days {
        case _ where days < 0:
            return ("Expired", .white.opacity(0.25), nil)
        case 0:
            return ("Last day!", Color(red: 0.95, green: 0.25, blue: 0.25), "exclamationmark.circle.fill")
        case 1...2:
            return ("\(days) day\(days == 1 ? "" : "s") left", Color(red: 0.95, green: 0.40, blue: 0.30), "clock.badge.exclamationmark")
        case 3...5:
            return ("\(days) days left", Color(red: 1.0, green: 0.75, blue: 0.25), "clock")
        default:
            return ("\(days) days left", .white.opacity(0.4), nil)
        }
    }

    private var validityFallback: String {
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

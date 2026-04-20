//
//  PromoValidity.swift
//  Scandalicious
//
//  One source of truth for "days remaining" countdown + urgency styling.
//  Replaces the three duplicated copies across PromoProductCard,
//  PromoProductDetailSheet, and PromoFolderModels.
//

import SwiftUI

enum PromoValidity {

    /// Parse "YYYY-MM-DD" → whole days until that date (relative to start-of-today).
    /// Negative when expired. Returns nil on an unparseable string.
    static func daysRemaining(until validityEnd: String) -> Int? {
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

    struct Display {
        let text: String
        let color: Color
        let icon: String?
        let isUrgent: Bool
    }

    /// Display-ready text + colour + icon based on the validity window.
    static func display(for validityEnd: String) -> Display {
        guard let days = daysRemaining(until: validityEnd) else {
            return Display(text: fallbackText(for: validityEnd),
                           color: PromoDesign.urgencyRelaxed, icon: nil, isUrgent: false)
        }
        switch days {
        case _ where days < 0:
            return Display(text: "Verlopen", color: PromoDesign.urgencyExpired, icon: nil, isUrgent: false)
        case 0:
            return Display(text: "Laatste dag!",
                           color: PromoDesign.urgencyUrgent,
                           icon: "exclamationmark.circle.fill",
                           isUrgent: true)
        case 1...2:
            return Display(text: "Nog \(days) dag\(days == 1 ? "" : "en")",
                           color: PromoDesign.urgencySoon,
                           icon: "clock.badge.exclamationmark",
                           isUrgent: true)
        case 3...5:
            return Display(text: "Nog \(days) dagen",
                           color: PromoDesign.urgencyWarn,
                           icon: "clock",
                           isUrgent: false)
        default:
            return Display(text: "Nog \(days) dagen",
                           color: PromoDesign.urgencyRelaxed,
                           icon: nil,
                           isUrgent: false)
        }
    }

    private static func fallbackText(for validityEnd: String) -> String {
        let parts = validityEnd.split(separator: "-")
        if parts.count == 3 { return "T/m \(parts[2])/\(parts[1])" }
        return validityEnd
    }
}

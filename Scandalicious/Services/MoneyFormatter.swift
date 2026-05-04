//
//  MoneyFormatter.swift
//  Scandalicious
//
//  Centralized EUR formatting. Backend ships money as integer cents; the app
//  speaks in cents internally and formats only at render time.
//

import Foundation

enum MoneyFormatter {
    /// Render integer cents as "€12.50". Negative amounts retain the sign.
    static func eur(cents: Int) -> String {
        let euros = Double(cents) / 100.0
        return String(format: "€%.2f", euros)
    }

    /// Render a Double EUR amount as "€12.50". Used when the backend hands us
    /// a float (e.g. legacy withdrawal `amount`).
    static func eur(_ euros: Double) -> String {
        return String(format: "€%.2f", euros)
    }
}

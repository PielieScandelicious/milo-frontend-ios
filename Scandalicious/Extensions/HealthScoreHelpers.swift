//
//  HealthScoreHelpers.swift
//  Scandalicious
//
//  Created by Claude on 21/01/2026.
//

import SwiftUI

// MARK: - Health Score Color & Label Extensions

extension Int {
    /// Returns the color for a health score (0-5)
    var healthScoreColor: Color {
        switch self {
        case 5:
            return Color(red: 0.2, green: 0.8, blue: 0.4)   // Vibrant green
        case 4:
            return Color(red: 0.4, green: 0.8, blue: 0.5)   // Light green
        case 3:
            return Color(red: 0.95, green: 0.8, blue: 0.3)  // Yellow
        case 2:
            return Color(red: 1.0, green: 0.6, blue: 0.3)   // Orange
        case 1:
            return Color(red: 1.0, green: 0.4, blue: 0.3)   // Red-orange
        case 0:
            return Color(red: 0.9, green: 0.3, blue: 0.3)   // Red
        default:
            return Color(white: 0.5)                         // Gray for invalid
        }
    }

    /// Returns a descriptive label for a health score (0-5)
    var healthScoreLabel: String {
        switch self {
        case 5:
            return "Very Healthy"
        case 4:
            return "Healthy"
        case 3:
            return "Moderate"
        case 2:
            return "Less Healthy"
        case 1:
            return "Unhealthy"
        case 0:
            return "Very Unhealthy"
        default:
            return "Unknown"
        }
    }

    /// Returns a short label for a health score (0-5)
    var healthScoreShortLabel: String {
        switch self {
        case 5:
            return "Great"
        case 4:
            return "Good"
        case 3:
            return "OK"
        case 2:
            return "Fair"
        case 1:
            return "Poor"
        case 0:
            return "Bad"
        default:
            return "N/A"
        }
    }

    /// Returns the Nutri-Score letter grade (A-E) for a health score (0-5)
    var nutriScoreLetter: String {
        switch self {
        case 5:
            return "A"
        case 4:
            return "B"
        case 3:
            return "C"
        case 2:
            return "D"
        case 1, 0:
            return "E"
        default:
            return "-"
        }
    }

    /// Returns an SF Symbol icon for a health score (0-5)
    var healthScoreIcon: String {
        switch self {
        case 5:
            return "leaf.fill"
        case 4:
            return "heart.fill"
        case 3:
            return "hand.thumbsup.fill"
        case 2:
            return "exclamationmark.triangle.fill"
        case 1:
            return "xmark.circle.fill"
        case 0:
            return "nosign"
        default:
            return "questionmark.circle.fill"
        }
    }

    /// Returns a description of what items typically have this score
    var healthScoreDescription: String {
        switch self {
        case 5:
            return "Fresh vegetables, fruits, water"
        case 4:
            return "Whole grains, lean proteins, eggs"
        case 3:
            return "Bread, pasta, cheese"
        case 2:
            return "Processed meats, sweetened drinks"
        case 1:
            return "Chips, candy, cookies, sodas"
        case 0:
            return "Alcohol, energy drinks"
        default:
            return "Non-food item"
        }
    }
}

extension Optional where Wrapped == Int {
    /// Returns the color for an optional health score
    var healthScoreColor: Color {
        guard let score = self else {
            return Color(white: 0.5) // Gray for non-food items
        }
        return score.healthScoreColor
    }

    /// Returns a label for an optional health score
    var healthScoreLabel: String {
        guard let score = self else {
            return "Non-Food"
        }
        return score.healthScoreLabel
    }

    /// Returns an icon for an optional health score
    var healthScoreIcon: String {
        guard let score = self else {
            return "cart.fill"
        }
        return score.healthScoreIcon
    }

    /// Returns the Nutri-Score letter grade (A-E) for an optional health score
    var nutriScoreLetter: String {
        guard let score = self else {
            return "-"
        }
        return score.nutriScoreLetter
    }
}

extension Double {
    /// Returns the color for an average health score (0.0-5.0)
    var healthScoreColor: Color {
        switch self {
        case 4.0...:
            return Color(red: 0.3, green: 0.8, blue: 0.45)  // Green blend
        case 3.0..<4.0:
            return Color(red: 0.7, green: 0.75, blue: 0.35) // Yellow-green
        case 2.0..<3.0:
            return Color(red: 0.95, green: 0.7, blue: 0.3)  // Orange-yellow
        case 1.0..<2.0:
            return Color(red: 1.0, green: 0.5, blue: 0.3)   // Orange
        case 0.0..<1.0:
            return Color(red: 0.9, green: 0.35, blue: 0.3)  // Red
        default:
            return Color(white: 0.5)
        }
    }

    /// Returns a label for an average health score
    var healthScoreLabel: String {
        switch self {
        case 4.5...:
            return "Very Healthy"
        case 4.0..<4.5:
            return "Healthy"
        case 3.0..<4.0:
            return "Moderate"
        case 2.0..<3.0:
            return "Less Healthy"
        case 1.0..<2.0:
            return "Unhealthy"
        case 0.0..<1.0:
            return "Very Unhealthy"
        default:
            return "Unknown"
        }
    }

    /// Formatted health score string (e.g., "3.5")
    var formattedHealthScore: String {
        String(format: "%.1f", self)
    }
}

extension Optional where Wrapped == Double {
    /// Returns the color for an optional average health score
    var healthScoreColor: Color {
        guard let score = self else {
            return Color(white: 0.5)
        }
        return score.healthScoreColor
    }

    /// Returns a label for an optional average health score
    var healthScoreLabel: String {
        guard let score = self else {
            return "No Data"
        }
        return score.healthScoreLabel
    }

    /// Formatted health score string or placeholder
    var formattedHealthScore: String {
        guard let score = self else {
            return "-"
        }
        return score.formattedHealthScore
    }
}

// MARK: - Health Score Calculation Helpers

extension Array where Element == Int? {
    /// Calculate average health score, ignoring nil values (non-food items)
    var averageHealthScore: Double? {
        let validScores = self.compactMap { $0 }
        guard !validScores.isEmpty else { return nil }
        return Double(validScores.reduce(0, +)) / Double(validScores.count)
    }
}

extension Array where Element == Int {
    /// Calculate average health score
    var averageHealthScore: Double {
        guard !self.isEmpty else { return 0.0 }
        return Double(self.reduce(0, +)) / Double(self.count)
    }
}

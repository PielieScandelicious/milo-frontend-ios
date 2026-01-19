//
//  CategoryColorExtension.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

// MARK: - Shared Category Color Logic
extension String {
    /// Intelligently assigns colors to categories based on their names and health characteristics
    var categoryColor: Color {
        let categoryName = self.lowercased()
        
        // Healthy categories - Green tones
        if categoryName.contains("fruit") || categoryName.contains("vegetable") ||
           categoryName.contains("salad") || categoryName.contains("greens") ||
           categoryName.contains("organic") || categoryName.contains("fresh produce") ||
           categoryName.contains("produce") {
            return Color(red: 0.2, green: 0.8, blue: 0.4)  // Vibrant green
        }
        
        // Unhealthy categories - Red tones
        if categoryName.contains("snack") || categoryName.contains("sweet") ||
           categoryName.contains("candy") || categoryName.contains("chocolate") ||
           categoryName.contains("chips") || categoryName.contains("cookie") ||
           categoryName.contains("dessert") || categoryName.contains("cake") ||
           categoryName.contains("ice cream") || categoryName.contains("soda") ||
           categoryName.contains("soft") && categoryName.contains("drink") {
            return Color(red: 1.0, green: 0.3, blue: 0.3)  // Vibrant red
        }
        
        // Alcohol - Deep red/wine color
        if categoryName.contains("alcohol") || categoryName.contains("beer") ||
           categoryName.contains("wine") || categoryName.contains("spirit") {
            return Color(red: 0.8, green: 0.2, blue: 0.3)  // Deep red
        }
        
        // Meat & Fish - Orange/salmon
        if categoryName.contains("meat") || categoryName.contains("fish") ||
           categoryName.contains("poultry") || categoryName.contains("seafood") ||
           categoryName.contains("chicken") || categoryName.contains("beef") {
            return Color(red: 1.0, green: 0.6, blue: 0.3)  // Orange/salmon
        }
        
        // Dairy - Light blue
        if categoryName.contains("dairy") || categoryName.contains("milk") ||
           categoryName.contains("cheese") || categoryName.contains("yogurt") ||
           categoryName.contains("egg") {
            return Color(red: 0.4, green: 0.7, blue: 1.0)  // Light blue
        }
        
        // Bakery & Bread - Warm yellow/tan
        if categoryName.contains("bakery") || categoryName.contains("bread") ||
           categoryName.contains("pastry") || categoryName.contains("bake") {
            return Color(red: 0.95, green: 0.8, blue: 0.4)  // Warm yellow
        }
        
        // Household & Cleaning - Purple
        if categoryName.contains("household") || categoryName.contains("cleaning") ||
           categoryName.contains("detergent") || categoryName.contains("supplies") {
            return Color(red: 0.7, green: 0.5, blue: 1.0)  // Purple
        }
        
        // Personal Care - Pink
        if categoryName.contains("personal") || categoryName.contains("care") ||
           categoryName.contains("hygiene") || categoryName.contains("cosmetic") ||
           categoryName.contains("beauty") {
            return Color(red: 1.0, green: 0.6, blue: 0.8)  // Pink
        }
        
        // Drinks (general, non-alcoholic) - Cyan
        if categoryName.contains("drink") || categoryName.contains("beverage") ||
           categoryName.contains("juice") || categoryName.contains("water") {
            return Color(red: 0.3, green: 0.85, blue: 0.9)  // Cyan
        }
        
        // Frozen foods - Ice blue
        if categoryName.contains("frozen") {
            return Color(red: 0.5, green: 0.8, blue: 0.95)  // Ice blue
        }
        
        // Canned/Preserved - Brown
        if categoryName.contains("canned") || categoryName.contains("preserved") {
            return Color(red: 0.7, green: 0.5, blue: 0.3)  // Brown
        }
        
        // Pantry/General - Brown
        if categoryName.contains("pantry") {
            return Color(red: 0.7, green: 0.5, blue: 0.3)  // Brown
        }
        
        // Ready meals - Orange
        if categoryName.contains("ready") || categoryName.contains("meal") {
            return Color(red: 1.0, green: 0.6, blue: 0.4)  // Coral
        }
        
        // Default fallback colors for uncategorized items
        let fallbackColors: [Color] = [
            Color(red: 0.6, green: 0.7, blue: 0.8),   // Gray-blue
            Color(red: 0.8, green: 0.7, blue: 0.6),   // Tan
            Color(red: 0.7, green: 0.6, blue: 0.7),   // Mauve
            Color(red: 0.6, green: 0.8, blue: 0.7),   // Mint
        ]
        
        // Use hash of category name to consistently assign same color
        let hash = abs(categoryName.hashValue)
        return fallbackColors[hash % fallbackColors.count]
    }
}

//
//  CategoryColorExtension.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

// MARK: - Category Icon Lookup
extension String {
    /// Get SF Symbol icon for a category based on its name (matches group)
    var categoryIcon: String {
        let name = self.lowercased()

        // Food & Dining group
        if name.contains("produce") || name.contains("fruit") || name.contains("veg") { return "leaf.fill" }
        if name.contains("meat") || name.contains("poultry") || name.contains("seafood") || name.contains("fish") { return "fork.knife" }
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") { return "mug.fill" }
        if name.contains("bakery") || name.contains("bread") { return "croissant.fill" }
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") { return "cabinet.fill" }
        if name.contains("frozen") { return "snowflake" }
        if name.contains("snack") || name.contains("candy") { return "birthday.cake.fill" }
        if name.contains("beverage") || name.contains("non-alcoholic") { return "cup.and.saucer.fill" }
        if name.contains("baby food") || name.contains("formula") { return "figure.and.child.holdinghands" }
        if name.contains("pet food") || name.contains("pet supplies") { return "pawprint.fill" }
        if name.contains("household consumable") || name.contains("paper/cleaning") { return "house.fill" }
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") { return "sparkles" }
        if name.contains("ready meal") || name.contains("prepared food") { return "takeoutbag.and.cup.and.straw.fill" }
        if name.contains("tobacco") { return "smoke.fill" }
        if name.contains("fast food") || name.contains("quick service") { return "takeoutbag.and.cup.and.straw.fill" }
        if name.contains("restaurant") || name.contains("sit-down") { return "fork.knife" }
        if name.contains("coffee") || name.contains("cafe") { return "cup.and.saucer.fill" }
        if name.contains("bar") || name.contains("nightlife") { return "wineglass.fill" }
        if name.contains("delivery") { return "bicycle" }
        if name.contains("liquor") || name.contains("wine shop") || name.contains("beer") || name.contains("alcohol") { return "wineglass.fill" }

        // Housing & Utilities
        if name.contains("rent") || name.contains("mortgage") || name.contains("property tax") { return "house.fill" }
        if name.contains("electric") || name.contains("water") || name.contains("gas") || name.contains("heating") || name.contains("trash") { return "bolt.fill" }
        if name.contains("internet") || name.contains("wi-fi") || name.contains("cable") || name.contains("phone") || name.contains("mobile") { return "wifi" }
        if name.contains("repair") || name.contains("plumbing") || name.contains("lawn") || name.contains("cleaning service") || name.contains("furniture") || name.contains("home improvement") { return "wrench.fill" }

        // Transportation
        if name.contains("car payment") || name.contains("auto insurance") || name.contains("registration") { return "car.fill" }
        if name.contains("fuel") || name.contains("gas/diesel") { return "fuelpump.fill" }
        if name.contains("maintenance") || name.contains("oil change") || name.contains("car wash") { return "car.fill" }
        if name.contains("uber") || name.contains("lyft") || name.contains("ride share") || name.contains("taxi") { return "car.fill" }
        if name.contains("transit") || name.contains("bus") || name.contains("train") { return "bus.fill" }
        if name.contains("parking") || name.contains("toll") { return "p.square.fill" }
        if name.contains("bike") || name.contains("scooter") { return "bicycle" }

        // Health & Wellness
        if name.contains("doctor") || name.contains("specialist") || name.contains("dental") || name.contains("vision") || name.contains("optometry") { return "heart.fill" }
        if name.contains("pharmacy") || name.contains("prescription") { return "pills.fill" }
        if name.contains("insurance") { return "shield.fill" }
        if name.contains("gym") || name.contains("sport") || name.contains("vitamin") || name.contains("supplement") { return "figure.run" }
        if name.contains("therapy") || name.contains("counseling") { return "brain.head.profile" }

        // Shopping & Personal Care
        if name.contains("apparel") || name.contains("clothing") || name.contains("shoes") || name.contains("footwear") { return "tshirt.fill" }
        if name.contains("jewelry") || name.contains("watch") { return "sparkle" }
        if name.contains("computer") || name.contains("tablet") || name.contains("gaming") || name.contains("console") { return "desktopcomputer" }
        if name.contains("software") { return "app.badge.fill" }
        if name.contains("salon") || name.contains("barber") || name.contains("spa") || name.contains("massage") || name.contains("cosmetic") || name.contains("makeup") || name.contains("nail") { return "sparkles" }

        // Entertainment & Leisure
        if name.contains("streaming") || name.contains("netflix") || name.contains("hulu") { return "play.tv.fill" }
        if name.contains("spotify") || name.contains("music") && name.contains("streaming") { return "headphones" }
        if name.contains("news") || name.contains("magazine") { return "newspaper.fill" }
        if name.contains("movie") || name.contains("theater") || name.contains("concert") || name.contains("festival") { return "film.fill" }
        if name.contains("museum") || name.contains("exhibition") { return "building.columns.fill" }
        if name.contains("book") || name.contains("audiobook") { return "book.fill" }
        if name.contains("art") || name.contains("craft") || name.contains("photography") || name.contains("instrument") { return "paintbrush.fill" }

        // Financial & Legal
        if name.contains("emergency") || name.contains("retirement") || name.contains("investment") || name.contains("crypto") || name.contains("saving") { return "banknote.fill" }
        if name.contains("credit card") || name.contains("student loan") || name.contains("personal loan") || name.contains("debt") { return "creditcard.fill" }
        if name.contains("bank fee") || name.contains("tax") || name.contains("legal") { return "doc.text.fill" }

        // Family & Education
        if name.contains("tuition") || name.contains("textbook") || name.contains("online course") { return "graduationcap.fill" }
        if name.contains("daycare") || name.contains("babysit") || name.contains("toy") || name.contains("extracurricular") || name.contains("baby supplies") || name.contains("diaper") { return "figure.and.child.holdinghands" }
        if name.contains("veterinary") || name.contains("pet groom") || name.contains("pet sit") || name.contains("boarding") { return "pawprint.fill" }

        // Travel & Vacation
        if name.contains("airfare") || name.contains("flight") { return "airplane" }
        if name.contains("hotel") || name.contains("resort") || name.contains("airbnb") || name.contains("vacation rental") { return "bed.double.fill" }
        if name.contains("car rental") || name.contains("cruise") { return "car.fill" }
        if name.contains("sightseeing") || name.contains("tour") || name.contains("souvenir") { return "map.fill" }
        if name.contains("travel insurance") { return "shield.fill" }

        // Gifts & Donations
        if name.contains("gift") { return "gift.fill" }
        if name.contains("charit") || name.contains("donat") || name.contains("tith") || name.contains("political") { return "heart.fill" }

        // Miscellaneous
        if name.contains("cash withdrawal") { return "banknote.fill" }
        if name.contains("reimbursement") || name.contains("adjustment") || name.contains("correction") { return "arrow.uturn.left.circle.fill" }
        if name.contains("unknown") { return "questionmark.circle.fill" }

        // Legacy category names (for backward compatibility)
        if name.contains("personal care") { return "sparkles" }
        if name.contains("household") { return "house.fill" }
        if name.contains("pet") { return "pawprint.fill" }
        if name.contains("baby") { return "figure.and.child.holdinghands" }
        if name.contains("ready") || name.contains("meal") { return "takeoutbag.and.cup.and.straw.fill" }
        if name.contains("drink") || name.contains("soda") || name.contains("soft") { return "cup.and.saucer.fill" }
        if name.contains("water") { return "waterbottle.fill" }
        if name.contains("sweet") { return "birthday.cake.fill" }
        if name == "other" { return "shippingbox.fill" }

        return "square.grid.2x2.fill"
    }
}

// MARK: - Premium High-Contrast Category Colors
extension String {
    /// Intelligently assigns premium, high-contrast colors to categories
    var categoryColor: Color {
        let categoryName = self.lowercased()

        // Healthy categories - Vibrant Emerald Green
        if categoryName.contains("fruit") || categoryName.contains("vegetable") ||
           categoryName.contains("salad") || categoryName.contains("greens") ||
           categoryName.contains("organic") || categoryName.contains("fresh produce") ||
           categoryName.contains("produce") {
            return Color(red: 0.18, green: 0.80, blue: 0.44)  // Emerald green
        }

        // Unhealthy categories - Vivid Coral Red
        if categoryName.contains("snack") || categoryName.contains("sweet") ||
           categoryName.contains("candy") || categoryName.contains("chocolate") ||
           categoryName.contains("chips") || categoryName.contains("cookie") ||
           categoryName.contains("dessert") || categoryName.contains("cake") ||
           categoryName.contains("ice cream") || categoryName.contains("soda") ||
           categoryName.contains("soft") && categoryName.contains("drink") {
            return Color(red: 1.0, green: 0.36, blue: 0.42)  // Coral red
        }

        // Alcohol - Rich Burgundy
        if categoryName.contains("alcohol") || categoryName.contains("beer") ||
           categoryName.contains("wine") || categoryName.contains("spirit") {
            return Color(red: 0.72, green: 0.15, blue: 0.30)  // Burgundy
        }

        // Meat & Fish - Warm Amber Orange
        if categoryName.contains("meat") || categoryName.contains("fish") ||
           categoryName.contains("poultry") || categoryName.contains("seafood") ||
           categoryName.contains("chicken") || categoryName.contains("beef") {
            return Color(red: 1.0, green: 0.58, blue: 0.20)  // Amber orange
        }

        // Dairy - Electric Sky Blue
        if categoryName.contains("dairy") || categoryName.contains("milk") ||
           categoryName.contains("cheese") || categoryName.contains("yogurt") ||
           categoryName.contains("egg") {
            return Color(red: 0.25, green: 0.72, blue: 1.0)  // Electric blue
        }

        // Bakery & Bread - Golden Yellow
        if categoryName.contains("bakery") || categoryName.contains("bread") ||
           categoryName.contains("pastry") || categoryName.contains("bake") {
            return Color(red: 1.0, green: 0.78, blue: 0.22)  // Golden yellow
        }

        // Household & Cleaning - Royal Purple
        if categoryName.contains("household") || categoryName.contains("cleaning") ||
           categoryName.contains("detergent") || categoryName.contains("supplies") {
            return Color(red: 0.55, green: 0.35, blue: 0.95)  // Royal purple
        }

        // Personal Care - Vivid Magenta Pink
        if categoryName.contains("personal") || categoryName.contains("care") ||
           categoryName.contains("hygiene") || categoryName.contains("cosmetic") ||
           categoryName.contains("beauty") {
            return Color(red: 0.95, green: 0.35, blue: 0.65)  // Magenta pink
        }

        // Drinks (general, non-alcoholic) - Bright Teal
        if categoryName.contains("drink") || categoryName.contains("beverage") ||
           categoryName.contains("juice") || categoryName.contains("water") {
            return Color(red: 0.15, green: 0.82, blue: 0.78)  // Bright teal
        }

        // Frozen foods - Icy Cyan
        if categoryName.contains("frozen") {
            return Color(red: 0.40, green: 0.85, blue: 0.98)  // Icy cyan
        }

        // Canned/Preserved - Rich Bronze
        if categoryName.contains("canned") || categoryName.contains("preserved") {
            return Color(red: 0.80, green: 0.55, blue: 0.25)  // Bronze
        }

        // Pantry/General - Warm Copper
        if categoryName.contains("pantry") {
            return Color(red: 0.85, green: 0.50, blue: 0.30)  // Copper
        }

        // Ready meals - Sunset Orange
        if categoryName.contains("ready") || categoryName.contains("meal") {
            return Color(red: 1.0, green: 0.50, blue: 0.30)  // Sunset orange
        }

        // "Other" category - Soft Steel
        if categoryName == "other" {
            return Color(red: 0.55, green: 0.58, blue: 0.65)  // Steel gray
        }

        // Housing & Utilities - Royal Purple
        if categoryName.contains("rent") || categoryName.contains("mortgage") || categoryName.contains("property tax") ||
           categoryName.contains("hoa") || categoryName.contains("syndic") ||
           categoryName.contains("electric") || categoryName.contains("water & sewer") ||
           categoryName.contains("heating") || categoryName.contains("trash") ||
           categoryName.contains("internet") || categoryName.contains("cable") ||
           categoryName.contains("phone") || categoryName.contains("security service") ||
           categoryName.contains("repair") || categoryName.contains("plumbing") ||
           categoryName.contains("lawn") || categoryName.contains("furniture") ||
           categoryName.contains("home improvement") {
            return Color(red: 0.56, green: 0.27, blue: 0.68)  // Royal purple
        }

        // Transportation - Electric Blue
        if categoryName.contains("car payment") || categoryName.contains("auto insurance") ||
           categoryName.contains("registration") || categoryName.contains("fuel") ||
           categoryName.contains("gas/diesel") || categoryName.contains("maintenance") ||
           categoryName.contains("oil change") || categoryName.contains("car wash") ||
           categoryName.contains("uber") || categoryName.contains("lyft") || categoryName.contains("ride share") ||
           categoryName.contains("transit") || categoryName.contains("taxi") ||
           categoryName.contains("parking") || categoryName.contains("toll") ||
           categoryName.contains("bike") || categoryName.contains("scooter") {
            return Color(red: 0.20, green: 0.60, blue: 0.86)  // Electric blue
        }

        // Health & Wellness - Coral Red
        if categoryName.contains("doctor") || categoryName.contains("specialist") ||
           categoryName.contains("dental") || categoryName.contains("vision") ||
           categoryName.contains("optometry") || categoryName.contains("pharmacy") ||
           categoryName.contains("prescription") || categoryName.contains("insurance premium") ||
           categoryName.contains("life insurance") || categoryName.contains("disability insurance") ||
           categoryName.contains("gym") || categoryName.contains("sports equipment") ||
           categoryName.contains("vitamin") || categoryName.contains("supplement") ||
           categoryName.contains("therapy") || categoryName.contains("counseling") {
            return Color(red: 0.91, green: 0.30, blue: 0.24)  // Coral red
        }

        // Entertainment & Leisure - Golden Yellow
        if categoryName.contains("streaming") || categoryName.contains("netflix") ||
           categoryName.contains("spotify") || categoryName.contains("news") ||
           categoryName.contains("magazine") || categoryName.contains("movie") ||
           categoryName.contains("theater") || categoryName.contains("concert") ||
           categoryName.contains("festival") || categoryName.contains("sporting event") ||
           categoryName.contains("museum") || categoryName.contains("exhibition") ||
           categoryName.contains("arts") || categoryName.contains("crafts") ||
           categoryName.contains("book") || categoryName.contains("audiobook") ||
           categoryName.contains("instrument") || categoryName.contains("photography") {
            return Color(red: 0.95, green: 0.77, blue: 0.06)  // Golden yellow
        }

        // Financial & Legal - Steel Gray
        if categoryName.contains("emergency fund") || categoryName.contains("retirement") ||
           categoryName.contains("investment") || categoryName.contains("brokerage") ||
           categoryName.contains("crypto") || categoryName.contains("credit card payment") ||
           categoryName.contains("student loan") || categoryName.contains("personal loan") ||
           categoryName.contains("bank fee") || categoryName.contains("overdraft") ||
           categoryName.contains("credit card interest") || categoryName.contains("income tax") ||
           categoryName.contains("tax prep") || categoryName.contains("legal fee") {
            return Color(red: 0.50, green: 0.55, blue: 0.55)  // Steel gray
        }

        // Family & Education - Warm Orange
        if categoryName.contains("tuition") || categoryName.contains("textbook") ||
           categoryName.contains("online course") || categoryName.contains("student loan interest") ||
           categoryName.contains("daycare") || categoryName.contains("babysit") ||
           categoryName.contains("toy") || categoryName.contains("extracurricular") ||
           categoryName.contains("baby supplies") || categoryName.contains("diaper") ||
           categoryName.contains("veterinary") || categoryName.contains("pet groom") ||
           categoryName.contains("pet sit") || categoryName.contains("boarding") {
            return Color(red: 0.90, green: 0.49, blue: 0.13)  // Warm orange
        }

        // Travel & Vacation - Sky Blue
        if categoryName.contains("airfare") || categoryName.contains("flight") ||
           categoryName.contains("hotel") || categoryName.contains("resort") ||
           categoryName.contains("airbnb") || categoryName.contains("vacation rental") ||
           categoryName.contains("car rental") || categoryName.contains("cruise") ||
           categoryName.contains("vacation dining") || categoryName.contains("sightseeing") ||
           categoryName.contains("tour") || categoryName.contains("souvenir") ||
           categoryName.contains("travel insurance") {
            return Color(red: 0.36, green: 0.68, blue: 0.88)  // Sky blue
        }

        // Gifts & Donations - Rose Pink
        if categoryName.contains("birthday gift") || categoryName.contains("holiday gift") ||
           categoryName.contains("wedding") || categoryName.contains("party gift") ||
           categoryName.contains("charitable") || categoryName.contains("donation") ||
           categoryName.contains("tithing") || categoryName.contains("political contribution") {
            return Color(red: 0.94, green: 0.38, blue: 0.57)  // Rose pink
        }

        // Restaurants & Dining Out - Sunset Orange
        if categoryName.contains("fast food") || categoryName.contains("quick service") ||
           categoryName.contains("sit-down restaurant") || categoryName.contains("restaurant") ||
           categoryName.contains("coffee shop") || categoryName.contains("cafe") ||
           categoryName.contains("bar") || categoryName.contains("nightlife") ||
           categoryName.contains("food delivery") || categoryName.contains("delivery (apps)") {
            return Color(red: 1.0, green: 0.50, blue: 0.30)  // Sunset orange
        }

        // Shopping - Magenta Pink
        if categoryName.contains("apparel") || categoryName.contains("clothing") ||
           categoryName.contains("shoes") || categoryName.contains("footwear") ||
           categoryName.contains("jewelry") || categoryName.contains("watch") ||
           categoryName.contains("dry cleaning") || categoryName.contains("tailoring") ||
           categoryName.contains("computer") || categoryName.contains("tablet") ||
           categoryName.contains("software subscription") || categoryName.contains("gaming") ||
           categoryName.contains("console") {
            return Color(red: 0.91, green: 0.12, blue: 0.55)  // Magenta pink
        }

        // Salon & Personal Care Services - Vivid Magenta
        if categoryName.contains("hair salon") || categoryName.contains("barber") ||
           categoryName.contains("spa") || categoryName.contains("massage") ||
           categoryName.contains("cosmetic") || categoryName.contains("makeup") ||
           categoryName.contains("nail salon") {
            return Color(red: 0.95, green: 0.35, blue: 0.65)  // Magenta pink
        }

        // Premium fallback colors for uncategorized items
        let fallbackColors: [Color] = [
            Color(red: 0.45, green: 0.70, blue: 0.95),   // Ocean blue
            Color(red: 0.90, green: 0.55, blue: 0.35),   // Terracotta
            Color(red: 0.65, green: 0.45, blue: 0.80),   // Lavender
            Color(red: 0.35, green: 0.75, blue: 0.60),   // Jade
        ]

        // Use hash of category name to consistently assign same color
        let hash = abs(categoryName.hashValue)
        return fallbackColors[hash % fallbackColors.count]
    }

    /// Returns hex color string for categories (for CategorySpendItem conversion)
    var categoryColorHex: String {
        return categoryColor.toHex()
    }
}

// MARK: - Grocery Sub-Category Health Theming
extension String {
    /// Health-gradient color for grocery sub-categories (green=healthy → red=unhealthy).
    /// Returns nil if this name is not a recognized grocery sub-category.
    var groceryHealthColor: Color? {
        let name = self.lowercased()

        // Very healthy → emerald green
        if name.contains("produce") || name.contains("fruit") || name.contains("veg") {
            return Color(red: 0.18, green: 0.80, blue: 0.44)
        }
        // Healthy → soft green
        if name.contains("baby food") || name.contains("formula") || name == "baby & kids" {
            return Color(red: 0.40, green: 0.78, blue: 0.47)
        }
        // Healthy → teal-green
        if name.contains("beverage") || name.contains("non-alcoholic") || name.contains("drink") && name.contains("water") {
            return Color(red: 0.15, green: 0.78, blue: 0.68)
        }
        // Healthy → blue-green
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") {
            return Color(red: 0.30, green: 0.75, blue: 0.65)
        }
        // Moderately healthy → yellow-green
        if name.contains("meat") || name.contains("poultry") || name.contains("seafood") || name.contains("fish") {
            return Color(red: 0.55, green: 0.78, blue: 0.35)
        }
        // Moderate → golden yellow
        if name.contains("bakery") || name.contains("bread") {
            return Color(red: 0.92, green: 0.78, blue: 0.28)
        }
        // Moderate → warm amber
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") {
            return Color(red: 0.88, green: 0.68, blue: 0.30)
        }
        // Neutral → icy blue
        if name.contains("frozen") {
            return Color(red: 0.40, green: 0.80, blue: 0.95)
        }
        // Non-food → muted brown
        if name.contains("pet food") || name.contains("pet supplies") || name == "pet supplies" {
            return Color(red: 0.65, green: 0.55, blue: 0.40)
        }
        // Non-food → muted purple
        if name.contains("household consumable") || name.contains("paper/cleaning") || name == "household" {
            return Color(red: 0.58, green: 0.48, blue: 0.78)
        }
        // Non-food → lavender pink
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") || name == "personal care" {
            return Color(red: 0.75, green: 0.48, blue: 0.72)
        }
        // Less healthy → orange
        if name.contains("ready meal") || name.contains("prepared food") || name == "ready meals" {
            return Color(red: 1.0, green: 0.55, blue: 0.25)
        }
        // Unhealthy → coral red
        if name.contains("snack") || name.contains("candy") || name.contains("sweet") {
            return Color(red: 1.0, green: 0.36, blue: 0.36)
        }
        // Drinks (soft/soda) → teal (not alcohol)
        if name.contains("drink") && (name.contains("soft") || name.contains("soda")) {
            return Color(red: 0.15, green: 0.78, blue: 0.68)
        }
        // Very unhealthy → dark red
        if name.contains("tobacco") {
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        }
        return nil
    }

    /// Health-themed SF Symbol icon for grocery sub-categories.
    /// Returns nil if this name is not a recognized grocery sub-category.
    var groceryHealthIcon: String? {
        let name = self.lowercased()
        if name.contains("produce") || name.contains("fruit") || name.contains("veg") { return "leaf.fill" }
        if name.contains("meat") || name.contains("poultry") || name.contains("seafood") || name.contains("fish") { return "fish.fill" }
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") { return "mug.fill" }
        if name.contains("bakery") || name.contains("bread") { return "croissant.fill" }
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") { return "cabinet.fill" }
        if name.contains("frozen") { return "snowflake" }
        if name.contains("snack") || name.contains("candy") || name.contains("sweet") { return "birthday.cake.fill" }
        if name.contains("beverage") || name.contains("non-alcoholic") { return "cup.and.saucer.fill" }
        if name.contains("drink") && (name.contains("soft") || name.contains("soda") || name.contains("water")) { return "cup.and.saucer.fill" }
        if name.contains("baby food") || name.contains("formula") || name.contains("baby") { return "figure.and.child.holdinghands" }
        if name.contains("pet food") || name.contains("pet supplies") || name.contains("pet") { return "pawprint.fill" }
        if name.contains("household") || name.contains("paper/cleaning") || name.contains("cleaning") { return "house.fill" }
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") || name == "personal care" { return "sparkles" }
        if name.contains("ready meal") || name.contains("prepared food") || name == "ready meals" { return "takeoutbag.and.cup.and.straw.fill" }
        if name.contains("tobacco") { return "smoke.fill" }
        return nil
    }
}

// MARK: - Color to Hex Extension
extension Color {
    /// Convert SwiftUI Color to hex string
    func toHex() -> String {
        // Convert to UIColor/NSColor components
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        #elseif canImport(AppKit)
        let uiColor = NSColor(self)
        #endif

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
        uiColor.usingColorSpace(.deviceRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

//
//  ExpenseCategory.swift
//  Scandalicious
//

import SwiftUI
import PhosphorSwift

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    // Fresh Food
    case fruits
    case vegetables
    case meatAndPoultry
    case charcuterieAndDeli
    case fishAndSeafood
    case dairyEggsCheese
    case bakery
    case pastries

    // Pantry & Staples
    case grainsAndPasta
    case cannedGoods
    case saucesAndCondiments
    case breakfastAndCereal
    case bakingAndFlour

    // Frozen
    case frozenIngredients
    case friesAndSnacks
    case readyMeals

    // Drinks
    case water
    case sodaAndJuice
    case coffeeAndTea
    case alcohol

    // Snacks
    case chipsAndNuts
    case chocolateAndSweets

    // Household
    case wasteBags
    case cleaning

    // Personal Care
    case pharmacy

    // Other
    case babyAndKids
    case petSupplies
    case tobacco
    case lottery
    case deposits
    case other

    var id: String { rawValue }

    // MARK: - Phosphor Icon

    var icon: some View {
        let img: Image
        switch self {
        case .fruits: img = Ph.appleLogo.fill
        case .vegetables: img = Ph.carrot.fill
        case .meatAndPoultry: img = Ph.bone.fill
        case .charcuterieAndDeli: img = Ph.bowlFood.fill
        case .fishAndSeafood: img = Ph.fish.fill
        case .dairyEggsCheese: img = Ph.cheese.fill
        case .bakery: img = Ph.bread.fill
        case .pastries: img = Ph.cookie.fill
        case .grainsAndPasta: img = Ph.grains.fill
        case .cannedGoods: img = Ph.jar.fill
        case .saucesAndCondiments: img = Ph.drop.fill
        case .breakfastAndCereal: img = Ph.sun.fill
        case .bakingAndFlour: img = Ph.cookingPot.fill
        case .frozenIngredients: img = Ph.snowflake.fill
        case .friesAndSnacks: img = Ph.fire.fill
        case .readyMeals: img = Ph.pizza.fill
        case .water: img = Ph.drop.fill
        case .sodaAndJuice: img = Ph.orangeSlice.fill
        case .coffeeAndTea: img = Ph.coffee.fill
        case .alcohol: img = Ph.wine.fill
        case .chipsAndNuts: img = Ph.popcorn.fill
        case .chocolateAndSweets: img = Ph.cookie.fill
        case .wasteBags: img = Ph.trash.fill
        case .cleaning: img = Ph.sparkle.fill
        case .pharmacy: img = Ph.pill.fill
        case .babyAndKids: img = Ph.baby.fill
        case .petSupplies: img = Ph.pawPrint.fill
        case .tobacco: img = Ph.cigarette.fill
        case .lottery: img = Ph.ticket.fill
        case .deposits: img = Ph.recycle.fill
        case .other: img = Ph.tag.fill
        }
        return img
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    /// Phosphor icon raw value for string-based rendering via Image.categorySymbol()
    var phIconName: String {
        switch self {
        case .fruits: return "apple-logo"
        case .vegetables: return "carrot"
        case .meatAndPoultry: return "bone"
        case .charcuterieAndDeli: return "bowl-food"
        case .fishAndSeafood: return "fish"
        case .dairyEggsCheese: return "cheese"
        case .bakery: return "bread"
        case .pastries: return "cookie"
        case .grainsAndPasta: return "grains"
        case .cannedGoods: return "jar"
        case .saucesAndCondiments: return "drop"
        case .breakfastAndCereal: return "sun"
        case .bakingAndFlour: return "cooking-pot"
        case .frozenIngredients: return "snowflake"
        case .friesAndSnacks: return "fire"
        case .readyMeals: return "pizza"
        case .water: return "drop"
        case .sodaAndJuice: return "orange-slice"
        case .coffeeAndTea: return "coffee"
        case .alcohol: return "wine"
        case .chipsAndNuts: return "popcorn"
        case .chocolateAndSweets: return "cookie"
        case .wasteBags: return "trash"
        case .cleaning: return "sparkle"
        case .pharmacy: return "pill"
        case .babyAndKids: return "baby"
        case .petSupplies: return "paw-print"
        case .tobacco: return "cigarette"
        case .lottery: return "ticket"
        case .deposits: return "recycle"
        case .other: return "tag"
        }
    }

    // MARK: - Color

    var color: Color {
        switch self {
        case .fruits: return .orange
        case .vegetables: return .green
        case .meatAndPoultry: return .red
        case .charcuterieAndDeli: return .pink
        case .fishAndSeafood: return .blue
        case .dairyEggsCheese: return .yellow
        case .bakery: return .brown
        case .pastries: return .purple
        case .grainsAndPasta: return Color(red: 0.6, green: 0.6, blue: 0.6)
        case .cannedGoods: return .gray
        case .saucesAndCondiments: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .breakfastAndCereal: return Color(red: 0.9, green: 0.6, blue: 0.2)
        case .bakingAndFlour: return Color(red: 0.8, green: 0.8, blue: 0.8)
        case .frozenIngredients: return .cyan
        case .friesAndSnacks: return .yellow
        case .readyMeals: return .orange
        case .water: return .blue
        case .sodaAndJuice: return .pink
        case .coffeeAndTea: return .brown
        case .alcohol: return .purple
        case .chipsAndNuts: return .yellow
        case .chocolateAndSweets: return .brown
        case .wasteBags: return .gray
        case .cleaning: return .mint
        case .pharmacy: return .red
        case .babyAndKids: return .teal
        case .petSupplies: return .orange
        case .tobacco: return .gray
        case .lottery: return .indigo
        case .deposits: return .green
        case .other: return .gray
        }
    }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .fruits: return L("cat_fruits")
        case .vegetables: return L("cat_vegetables")
        case .meatAndPoultry: return L("cat_meat_poultry")
        case .charcuterieAndDeli: return L("cat_charcuterie_salads")
        case .fishAndSeafood: return L("cat_fish_seafood")
        case .dairyEggsCheese: return L("cat_dairy_eggs_cheese")
        case .bakery: return L("cat_bakery")
        case .pastries: return L("cat_pastries")
        case .grainsAndPasta: return L("cat_grains_pasta_potatoes")
        case .cannedGoods: return L("cat_canned_jarred")
        case .saucesAndCondiments: return L("cat_sauces_condiments")
        case .breakfastAndCereal: return L("cat_breakfast_cereal")
        case .bakingAndFlour: return L("cat_baking_flour")
        case .frozenIngredients: return L("cat_frozen_ingredients")
        case .friesAndSnacks: return L("cat_fries_snacks")
        case .readyMeals: return L("cat_ready_meals")
        case .water: return L("cat_water")
        case .sodaAndJuice: return L("cat_soda_juices")
        case .coffeeAndTea: return L("cat_coffee_tea")
        case .alcohol: return L("cat_alcohol")
        case .chipsAndNuts: return L("cat_chips_nuts")
        case .chocolateAndSweets: return L("cat_chocolate_sweets")
        case .wasteBags: return L("cat_waste_bags")
        case .cleaning: return L("cat_cleaning")
        case .pharmacy: return L("cat_pharmacy_hygiene")
        case .babyAndKids: return L("cat_baby_kids")
        case .petSupplies: return L("cat_pet_supplies")
        case .tobacco: return L("cat_tobacco")
        case .lottery: return L("cat_lottery")
        case .deposits: return L("cat_deposits")
        case .other: return L("cat_other")
        }
    }

    var group: String {
        switch self {
        case .fruits, .vegetables, .meatAndPoultry, .charcuterieAndDeli,
             .fishAndSeafood, .dairyEggsCheese, .bakery, .pastries:
            return "Fresh Food"
        case .grainsAndPasta, .cannedGoods, .saucesAndCondiments,
             .breakfastAndCereal, .bakingAndFlour:
            return "Pantry & Staples"
        case .frozenIngredients, .friesAndSnacks, .readyMeals:
            return "Frozen"
        case .water, .sodaAndJuice, .coffeeAndTea, .alcohol:
            return "Drinks"
        case .chipsAndNuts, .chocolateAndSweets:
            return "Snacks"
        case .wasteBags, .cleaning:
            return "Household"
        case .pharmacy:
            return "Personal Care"
        case .babyAndKids, .petSupplies, .tobacco, .lottery, .deposits, .other:
            return "Other"
        }
    }

    // MARK: - Fuzzy Name Matching

    /// Match a display/backend name to an ExpenseCategory
    static func from(name: String) -> ExpenseCategory {
        let n = name.lowercased()

        // Exact display name match
        if let exact = allCases.first(where: { $0.displayName.lowercased() == n }) {
            return exact
        }

        // Exact raw value match
        if let exact = ExpenseCategory(rawValue: n) {
            return exact
        }

        // Fresh Food
        if n == "fruits" || n.contains("fruit") { return .fruits }
        if n == "vegetables" || n.contains("veg") || n.contains("produce") { return .vegetables }
        if n.contains("charcuterie") || n.contains("deli") || n.contains("preparé") { return .charcuterieAndDeli }
        if n.contains("meat") || n.contains("poultry") || n.contains("chicken") || n.contains("beef") { return .meatAndPoultry }
        if n.contains("seafood") || n.contains("fish") || n.contains("shrimp") { return .fishAndSeafood }
        if n.contains("dairy") || n.contains("cheese") || n.contains("egg") || n.contains("milk") || n.contains("yogurt") { return .dairyEggsCheese }
        if n.contains("pastry") || n.contains("pastries") || n.contains("koffiekoek") { return .pastries }
        if n.contains("bakery") || n.contains("bread") || n.contains("pistolet") { return .bakery }

        // Pantry & Staples
        if n.contains("grain") || n.contains("pasta") || n.contains("potato") || n.contains("rice") { return .grainsAndPasta }
        if n.contains("canned") || n.contains("jarred") { return .cannedGoods }
        if n.contains("sauce") || n.contains("mayo") || n.contains("condiment") { return .saucesAndCondiments }
        if n.contains("breakfast") || n.contains("cereal") { return .breakfastAndCereal }
        if n.contains("baking") || n.contains("flour") { return .bakingAndFlour }

        // Frozen
        if n.contains("frozen") && (n.contains("ingredient") || n.contains("veg") || n.contains("fruit")) { return .frozenIngredients }
        if n.contains("fries") || n.contains("frituur") || n.contains("snack") && n.contains("frozen") { return .friesAndSnacks }
        if n.contains("ready") || n.contains("pizza") || n.contains("prepared") { return .readyMeals }

        // Drinks
        if n.contains("water") && !n.contains("soda") { return .water }
        if n.contains("soda") || n.contains("juice") || n.contains("soft") { return .sodaAndJuice }
        if n.contains("coffee") || n.contains("tea") { return .coffeeAndTea }
        if n.contains("alcohol") || n.contains("beer") || n.contains("wine") || n.contains("spirit") ||
           n.contains("whisky") || n.contains("vodka") || n.contains("gin") || n.contains("cava") ||
           n.contains("champagne") || n.contains("cider") { return .alcohol }

        // Snacks
        if n.contains("chips") || n.contains("nuts") || n.contains("aperitif") { return .chipsAndNuts }
        if n.contains("chocolate") || n.contains("sweet") || n.contains("biscuit") || n.contains("candy") || n.contains("confectionery") { return .chocolateAndSweets }

        // Household
        if n.contains("waste") || n.contains("pmd") || n.contains("rest") { return .wasteBags }
        if n.contains("cleaning") || n.contains("paper") { return .cleaning }

        // Personal Care
        if n.contains("pharmacy") || n.contains("hygiene") || n.contains("personal") || n.contains("care") ||
           n.contains("shampoo") || n.contains("soap") || n.contains("cosmetic") { return .pharmacy }

        // Other
        if n.contains("baby") || n.contains("kids") || n.contains("formula") { return .babyAndKids }
        if n.contains("pet") { return .petSupplies }
        if n.contains("tobacco") { return .tobacco }
        if n.contains("lottery") || n.contains("scratch") { return .lottery }
        if n.contains("deposit") || n.contains("statiegeld") || n.contains("vidange") { return .deposits }

        // Generic frozen (after specific frozen checks)
        if n.contains("frozen") { return .frozenIngredients }

        // Legacy fallbacks
        if n.contains("snack") { return .chipsAndNuts }
        if n.contains("drink") || n.contains("beverage") || n.contains("non-alcoholic") { return .sodaAndJuice }
        if n.contains("household") || n.contains("supplies") || n.contains("detergent") { return .cleaning }
        if n == "pantry" { return .grainsAndPasta }

        return .other
    }
}

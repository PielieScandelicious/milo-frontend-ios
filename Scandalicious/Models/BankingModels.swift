//
//  BankingModels.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Bank List Response

struct BankListResponse: Codable {
    let banks: [BankInfo]
    let country: String
}

struct BankInfo: Codable, Identifiable {
    let name: String
    let country: String
    let bic: String?
    let logoUrl: String?
    let maxConsentDays: Int

    var id: String { bic ?? name }

    enum CodingKeys: String, CodingKey {
        case name
        case country
        case bic
        case logoUrl = "logo_url"
        case maxConsentDays = "max_consent_days"
    }
}

// MARK: - Bank Connection Models

struct BankConnectionCreate: Encodable {
    let bankName: String
    let country: String
    let callbackType: String

    enum CodingKeys: String, CodingKey {
        case bankName = "bank_name"
        case country
        case callbackType = "callback_type"
    }

    init(bankName: String, country: String) {
        self.bankName = bankName
        self.country = country
        self.callbackType = "mobile"
    }
}

struct BankConnectionAuthResponse: Codable {
    let connectionId: String
    let redirectUrl: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id"
        case redirectUrl = "redirect_url"
        case message
    }
}

struct BankConnectionListResponse: Codable {
    let connections: [BankConnectionResponse]
}

struct BankConnectionResponse: Codable, Identifiable {
    let id: String
    let aspspName: String
    let aspspCountry: String
    let status: BankConnectionStatus
    let validUntil: Date?
    let errorMessage: String?
    let createdAt: Date
    let accountsCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case aspspName = "aspsp_name"
        case aspspCountry = "aspsp_country"
        case status
        case validUntil = "valid_until"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case accountsCount = "accounts_count"
    }
}

enum BankConnectionStatus: String, Codable {
    case pending
    case active
    case expired
    case revoked
    case error

    var displayText: String {
        switch self {
        case .pending: return "Pending"
        case .active: return "Active"
        case .expired: return "Expired"
        case .revoked: return "Revoked"
        case .error: return "Error"
        }
    }

    var color: Color {
        switch self {
        case .pending: return Color(red: 1.0, green: 0.75, blue: 0.3)
        case .active: return Color(red: 0.3, green: 0.8, blue: 0.5)
        case .expired: return Color(red: 1.0, green: 0.6, blue: 0.3)
        case .revoked: return Color.gray
        case .error: return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .active: return "checkmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .revoked: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Bank Account Models

struct BankAccountListResponse: Codable {
    let accounts: [BankAccountResponse]
}

struct BankAccountResponse: Codable, Identifiable {
    let id: String
    let connectionId: String
    let iban: String?
    let accountName: String?
    let holderName: String?
    let currency: String
    let balance: Double?
    let lastSyncedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case connectionId = "connection_id"
        case iban
        case accountName = "account_name"
        case holderName = "holder_name"
        case currency
        case balance
        case lastSyncedAt = "last_synced_at"
    }

    var maskedIban: String? {
        guard let iban = iban, iban.count >= 4 else { return iban }
        let lastFour = String(iban.suffix(4))
        return "•••• \(lastFour)"
    }

    var displayName: String {
        accountName ?? holderName ?? maskedIban ?? "Account"
    }
}

struct BankAccountSyncResponse: Codable {
    let accountId: String
    let balance: Double?
    let transactionsFetched: Int
    let newTransactions: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case balance
        case transactionsFetched = "transactions_fetched"
        case newTransactions = "new_transactions"
        case message
    }
}

// MARK: - Bank Transaction Models

struct BankTransactionListResponse: Codable {
    let transactions: [BankTransactionResponse]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case transactions
        case total
        case page
        case pageSize = "page_size"
        case totalPages = "total_pages"
    }
}

struct BankTransactionResponse: Codable, Identifiable, Hashable {
    let id: String
    let accountId: String
    let amount: Double
    let currency: String
    let creditorName: String?
    let debtorName: String?
    let bookingDate: Date
    let description: String?
    let status: BankTransactionStatus
    let suggestedCategory: String?
    let categoryConfidence: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case amount
        case currency
        case creditorName = "creditor_name"
        case debtorName = "debtor_name"
        case bookingDate = "booking_date"
        case description
        case status
        case suggestedCategory = "suggested_category"
        case categoryConfidence = "category_confidence"
    }

    var counterpartyName: String {
        if amount < 0 {
            return creditorName ?? "Unknown Merchant"
        } else {
            return debtorName ?? "Unknown Sender"
        }
    }

    var isExpense: Bool {
        amount < 0
    }

    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "\(currency) \(abs(amount))"
    }

    var amountColor: Color {
        isExpense ? Color(red: 1.0, green: 0.4, blue: 0.4) : Color(red: 0.3, green: 0.8, blue: 0.5)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BankTransactionResponse, rhs: BankTransactionResponse) -> Bool {
        lhs.id == rhs.id
    }
}

enum BankTransactionStatus: String, Codable {
    case pending
    case imported
    case ignored

    var displayText: String {
        switch self {
        case .pending: return "Pending Review"
        case .imported: return "Imported"
        case .ignored: return "Ignored"
        }
    }
}

// MARK: - Transaction Import Models

struct TransactionImportRequest: Encodable {
    let transactions: [TransactionImportItem]
}

struct TransactionImportItem: Encodable {
    let bankTransactionId: String
    let category: String
    let storeName: String?
    let itemName: String?

    enum CodingKeys: String, CodingKey {
        case bankTransactionId = "bank_transaction_id"
        case category
        case storeName = "store_name"
        case itemName = "item_name"
    }
}

struct TransactionImportResponse: Codable {
    let importedCount: Int
    let failedCount: Int

    enum CodingKeys: String, CodingKey {
        case importedCount = "imported_count"
        case failedCount = "failed_count"
    }
}

struct TransactionIgnoreRequest: Encodable {
    let transactionIds: [String]

    enum CodingKeys: String, CodingKey {
        case transactionIds = "transaction_ids"
    }
}

// MARK: - Deep Link Callback Result

struct BankingCallbackResult {
    let connectionId: String?
    let status: CallbackStatus
    let accountCount: Int
    let errorMessage: String?

    enum CallbackStatus {
        case success
        case error
        case cancelled
    }
}

// MARK: - Country Model

struct BankingCountry: Identifiable, Hashable {
    let code: String
    let name: String
    let flag: String

    var id: String { code }

    static let supportedCountries: [BankingCountry] = [
        BankingCountry(code: "BE", name: "Belgium", flag: "🇧🇪"),
        BankingCountry(code: "NL", name: "Netherlands", flag: "🇳🇱"),
        BankingCountry(code: "DE", name: "Germany", flag: "🇩🇪"),
        BankingCountry(code: "FR", name: "France", flag: "🇫🇷"),
        BankingCountry(code: "ES", name: "Spain", flag: "🇪🇸"),
        BankingCountry(code: "IT", name: "Italy", flag: "🇮🇹"),
        BankingCountry(code: "GB", name: "United Kingdom", flag: "🇬🇧"),
        BankingCountry(code: "AT", name: "Austria", flag: "🇦🇹"),
        BankingCountry(code: "PT", name: "Portugal", flag: "🇵🇹"),
        BankingCountry(code: "FI", name: "Finland", flag: "🇫🇮"),
        BankingCountry(code: "IE", name: "Ireland", flag: "🇮🇪"),
        BankingCountry(code: "LU", name: "Luxembourg", flag: "🇱🇺"),
    ]

    static var defaultCountry: BankingCountry {
        supportedCountries.first { $0.code == "BE" } ?? supportedCountries[0]
    }
}

// MARK: - Grocery Categories

enum GroceryCategory: String, CaseIterable, Identifiable {
    case meatFish = "Meat & Fish"
    case alcohol = "Alcohol"
    case drinksSoftSoda = "Drinks (Soft/Soda)"
    case drinksWater = "Drinks (Water)"
    case household = "Household"
    case snacksSweets = "Snacks & Sweets"
    case freshProduce = "Fresh Produce"
    case dairyEggs = "Dairy & Eggs"
    case readyMeals = "Ready Meals"
    case bakery = "Bakery"
    case pantry = "Pantry"
    case personalCare = "Personal Care"
    case frozen = "Frozen"
    case babyKids = "Baby & Kids"
    case petSupplies = "Pet Supplies"
    case tobacco = "Tobacco"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .meatFish: return "fish.fill"
        case .alcohol: return "wineglass.fill"
        case .drinksSoftSoda: return "cup.and.saucer.fill"
        case .drinksWater: return "waterbottle.fill"
        case .household: return "house.fill"
        case .snacksSweets: return "birthday.cake.fill"
        case .freshProduce: return "leaf.fill"
        case .dairyEggs: return "carton.fill"
        case .readyMeals: return "takeoutbag.and.cup.and.straw.fill"
        case .bakery: return "croissant.fill"
        case .pantry: return "cabinet.fill"
        case .personalCare: return "sparkles"
        case .frozen: return "snowflake"
        case .babyKids: return "figure.and.child.holdinghands"
        case .petSupplies: return "pawprint.fill"
        case .tobacco: return "smoke.fill"
        case .other: return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .meatFish: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .alcohol: return Color(red: 0.6, green: 0.2, blue: 0.5)
        case .drinksSoftSoda: return Color(red: 1.0, green: 0.5, blue: 0.3)
        case .drinksWater: return Color(red: 0.3, green: 0.7, blue: 1.0)
        case .household: return Color(red: 0.5, green: 0.5, blue: 0.6)
        case .snacksSweets: return Color(red: 1.0, green: 0.4, blue: 0.6)
        case .freshProduce: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case .dairyEggs: return Color(red: 1.0, green: 0.9, blue: 0.5)
        case .readyMeals: return Color(red: 0.9, green: 0.5, blue: 0.2)
        case .bakery: return Color(red: 0.85, green: 0.65, blue: 0.4)
        case .pantry: return Color(red: 0.7, green: 0.5, blue: 0.3)
        case .personalCare: return Color(red: 0.7, green: 0.4, blue: 0.9)
        case .frozen: return Color(red: 0.5, green: 0.8, blue: 1.0)
        case .babyKids: return Color(red: 1.0, green: 0.7, blue: 0.8)
        case .petSupplies: return Color(red: 0.6, green: 0.4, blue: 0.3)
        case .tobacco: return Color(red: 0.4, green: 0.4, blue: 0.4)
        case .other: return Color(red: 0.5, green: 0.5, blue: 0.5)
        }
    }

    static func from(string: String?) -> GroceryCategory? {
        guard let string = string else { return nil }
        return GroceryCategory.allCases.first { $0.rawValue.lowercased() == string.lowercased() }
    }
}

// MARK: - Banking Notifications

extension Notification.Name {
    static let bankConnectionCompleted = Notification.Name("bankConnectionCompleted")
    static let bankConnectionFailed = Notification.Name("bankConnectionFailed")
    static let bankTransactionsImported = Notification.Name("bankTransactionsImported")
}

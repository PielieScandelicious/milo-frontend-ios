//
//  SubscriptionManager.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import Foundation
import StoreKit
import Combine

// Use type alias to avoid conflict with local Transaction model
typealias StoreKitTransaction = StoreKit.Transaction

/// Product identifiers for Scandalicious subscriptions
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.deepmaind.scandalicious.premium.monthly"
    case yearly = "com.deepmaind.scandalicious.premium.yearly"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

/// Subscription status for the user
enum SubscriptionStatus: Equatable {
    case notSubscribed
    case subscribed(expirationDate: Date, productId: String)
    case inTrial(expirationDate: Date, productId: String)
    case expired

    var isActive: Bool {
        switch self {
        case .subscribed, .inTrial:
            return true
        case .notSubscribed, .expired:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .notSubscribed:
            return "Not Subscribed"
        case .subscribed(let date, _):
            return "Active until \(date.formatted(date: .abbreviated, time: .omitted))"
        case .inTrial(let date, _):
            return "Free trial until \(date.formatted(date: .abbreviated, time: .omitted))"
        case .expired:
            return "Subscription Expired"
        }
    }
}

/// Manages all subscription-related functionality using StoreKit 2
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// Available subscription products
    @Published private(set) var products: [Product] = []

    /// Current subscription status
    // PAYWALL DISABLED: Always set to subscribed
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .subscribed(
        expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year from now
        productId: "com.deepmaind.scandalicious.premium.yearly"
    )

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message
    @Published var errorMessage: String?

    /// Purchase in progress
    @Published private(set) var isPurchasing = false

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load products and check status on init
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    /// Load available subscription products from the App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIds = SubscriptionProduct.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIds)

            // Sort products: yearly first (best value)
            products = storeProducts.sorted { product1, product2 in
                if product1.id.contains("yearly") { return true }
                if product2.id.contains("yearly") { return false }
                return product1.price < product2.price
            }

            print("✅ Loaded \(products.count) subscription products")
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options. Please try again."
        }
    }

    // MARK: - Purchase

    /// Purchase a subscription product
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                print("✅ Purchase successful for \(product.id)")
                return true

            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                return false

            case .pending:
                print("ℹ️ Purchase pending (may require approval)")
                errorMessage = "Purchase is pending approval."
                return false

            @unknown default:
                print("⚠️ Unknown purchase result")
                return false
            }
        } catch StoreKitError.userCancelled {
            print("ℹ️ User cancelled purchase")
            return false
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("✅ Purchases restored")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = "Failed to restore purchases. Please try again."
        }
    }

    // MARK: - Subscription Status

    /// Update the current subscription status by checking subscription products
    func updateSubscriptionStatus() async {
        // PAYWALL DISABLED: Always return active subscription
        subscriptionStatus = .subscribed(
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year from now
            productId: "com.deepmaind.scandalicious.premium.yearly"
        )
        print("✅ Paywall disabled - returning active subscription")
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates (renewals, revocations, etc.)
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            // Listen for unfinished transactions
            for await verificationResult in StoreKitTransaction.unfinished {
                guard let self = self else { return }

                if case .verified(let transaction) = verificationResult {
                    // Update subscription status on main actor
                    await MainActor.run {
                        Task {
                            await self.updateSubscriptionStatus()
                        }
                    }

                    // Always finish transactions
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers

    /// Verify a transaction result
    private func checkVerified(_ result: VerificationResult<StoreKitTransaction>) throws -> StoreKitTransaction {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    /// Get the monthly product
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthly.rawValue }
    }

    /// Get the yearly product
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.yearly.rawValue }
    }

    /// Calculate weekly price for a product
    func weeklyPrice(for product: Product) -> String {
        let yearlyWeeks = 52.0
        let monthlyWeeks = 4.33 // Average weeks per month

        let weeklyAmount: Decimal
        if product.id.contains("yearly") {
            weeklyAmount = product.price / Decimal(yearlyWeeks)
        } else {
            weeklyAmount = product.price / Decimal(monthlyWeeks)
        }

        // Format with the product's locale
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.maximumFractionDigits = 2

        return formatter.string(from: weeklyAmount as NSDecimalNumber) ?? "$\(weeklyAmount)"
    }

    /// Calculate savings percentage for yearly vs monthly
    func yearlySavingsPercentage() -> Int {
        guard let monthly = monthlyProduct, let yearly = yearlyProduct else { return 0 }

        let yearlyMonthlyCost = monthly.price * 12
        let yearlyCost = yearly.price
        let savings = (yearlyMonthlyCost - yearlyCost) / yearlyMonthlyCost * 100

        return Int(truncating: savings as NSDecimalNumber)
    }
}

// MARK: - Product Extensions

extension Product {
    /// Formatted price string
    var formattedPrice: String {
        self.displayPrice
    }

    /// Subscription period description
    var periodDescription: String {
        guard let subscription = self.subscription else { return "" }

        switch subscription.subscriptionPeriod.unit {
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "month" : "\(subscription.subscriptionPeriod.value) months"
        case .year:
            return subscription.subscriptionPeriod.value == 1 ? "year" : "\(subscription.subscriptionPeriod.value) years"
        case .week:
            return subscription.subscriptionPeriod.value == 1 ? "week" : "\(subscription.subscriptionPeriod.value) weeks"
        case .day:
            return subscription.subscriptionPeriod.value == 1 ? "day" : "\(subscription.subscriptionPeriod.value) days"
        @unknown default:
            return ""
        }
    }

    /// Trial period description
    var trialDescription: String? {
        guard let introOffer = self.subscription?.introductoryOffer else { return nil }

        if introOffer.paymentMode == .freeTrial {
            let period = introOffer.period
            switch period.unit {
            case .day:
                return "\(period.value)-day free trial"
            case .week:
                return "\(period.value * 7)-day free trial"
            case .month:
                return "\(period.value)-month free trial"
            case .year:
                return "\(period.value)-year free trial"
            @unknown default:
                return "Free trial"
            }
        }
        return nil
    }
}

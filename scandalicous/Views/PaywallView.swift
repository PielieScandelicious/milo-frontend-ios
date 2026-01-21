//
//  PaywallView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var showSuccessAnimation = false
    @State private var showSignOutConfirmation = false

    /// Whether this paywall is dismissible (false when it's the required paywall before app access)
    private var isDismissible: Bool {
        subscriptionManager.subscriptionStatus.isActive
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.4),
                    Color.blue.opacity(0.3),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Pricing cards
                    pricingSection

                    // Trial info
                    trialInfoSection

                    // Subscribe button
                    subscribeButton

                    // Restore & Terms
                    footerSection
                }
                .padding()
            }

            // Top bar with close/sign out buttons
            VStack {
                HStack {
                    // Sign out button (only when this is the required paywall)
                    if !isDismissible {
                        Button {
                            showSignOutConfirmation = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding()
                    }

                    Spacer()

                    // Close button (only when paywall is dismissible)
                    if isDismissible {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding()
                    }
                }
                Spacer()
            }

            // Success animation overlay
            if showSuccessAnimation {
                successOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Select yearly by default (best value)
            if selectedProduct == nil {
                selectedProduct = subscriptionManager.yearlyProduct
            }
        }
        .onChange(of: subscriptionManager.products) { _, products in
            if selectedProduct == nil, let yearly = subscriptionManager.yearlyProduct {
                selectedProduct = yearly
            }
        }
        .alert("Error", isPresented: .init(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("OK") { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                try? authManager.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out? You can sign in with a different account.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.top, 40)

            Text("Unlock Premium")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Get the most out of Scandalicious")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "chart.bar.fill", text: "Unlimited receipt scans")
            FeatureRow(icon: "brain.head.profile", text: "AI-powered spending insights")
            FeatureRow(icon: "heart.fill", text: "Detailed health scores")
            FeatureRow(icon: "chart.pie.fill", text: "Advanced analytics & reports")
            FeatureRow(icon: "sparkles", text: "Dobby AI assistant - unlimited chats")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: 12) {
            // Yearly option (best value)
            if let yearly = subscriptionManager.yearlyProduct {
                PricingCard(
                    product: yearly,
                    weeklyPrice: subscriptionManager.weeklyPrice(for: yearly),
                    isSelected: selectedProduct?.id == yearly.id,
                    savingsPercentage: subscriptionManager.yearlySavingsPercentage(),
                    isBestValue: true
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedProduct = yearly
                    }
                }
            }

            // Monthly option
            if let monthly = subscriptionManager.monthlyProduct {
                PricingCard(
                    product: monthly,
                    weeklyPrice: subscriptionManager.weeklyPrice(for: monthly),
                    isSelected: selectedProduct?.id == monthly.id,
                    savingsPercentage: nil,
                    isBestValue: false
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedProduct = monthly
                    }
                }
            }

            // Loading state
            if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
                ProgressView()
                    .padding(40)
            }
        }
    }

    // MARK: - Trial Info Section

    private var trialInfoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "gift.fill")
                .foregroundStyle(.green)

            Text("Start with a **14-day free trial**")
                .font(.subheadline)

            Text("Cancel anytime")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task {
                guard let product = selectedProduct else { return }
                let success = await subscriptionManager.purchase(product)
                if success {
                    withAnimation(.spring(response: 0.5)) {
                        showSuccessAnimation = true
                    }
                    // Dismiss after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Start Free Trial")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)
        .opacity(selectedProduct == nil ? 0.6 : 1)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button {
                    // Open terms URL
                    if let url = URL(string: "https://scandalicious.app/terms") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Terms of Use")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.5))

                Button {
                    // Open privacy URL
                    if let url = URL(string: "https://scandalicious.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Privacy Policy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showSuccessAnimation)

                Text("Welcome to Premium!")
                    .font(.title)
                    .fontWeight(.bold)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let product: Product
    let weeklyPrice: String
    let isSelected: Bool
    let savingsPercentage: Int?
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Best value badge
                if isBestValue, let savings = savingsPercentage, savings > 0 {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("BEST VALUE • SAVE \(savings)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .offset(y: -12)
                }

                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.id.contains("yearly") ? "Yearly" : "Monthly")
                                .font(.headline)
                                .fontWeight(.semibold)

                            if let trial = product.trialDescription {
                                Text(trial)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(product.displayPrice)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("per \(product.periodDescription)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                        .background(.white.opacity(0.2))

                    // Weekly breakdown
                    HStack {
                        Text("That's just")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(weeklyPrice)/week")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)

                        Spacer()

                        // Selection indicator
                        ZStack {
                            Circle()
                                .strokeBorder(isSelected ? Color.purple : Color.gray.opacity(0.5), lineWidth: 2)
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ?
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}

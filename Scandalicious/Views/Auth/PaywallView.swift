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

    private var isDismissible: Bool {
        subscriptionManager.subscriptionStatus.isActive
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.05, blue: 0.3),
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // Header with Milo icon
                headerSection

                Spacer()

                // Features row
                featuresSection
                    .padding(.horizontal, 20)

                Spacer()

                // Pricing cards
                pricingSection
                    .padding(.horizontal, 20)

                Spacer()

                // Subscribe button
                subscribeButton
                    .padding(.horizontal, 20)

                // Footer
                footerSection
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            // Success overlay
            if showSuccessAnimation {
                successOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if selectedProduct == nil {
                selectedProduct = subscriptionManager.yearlyProduct
            }
        }
        .onChange(of: subscriptionManager.products) { _, _ in
            if selectedProduct == nil, let yearly = subscriptionManager.yearlyProduct {
                selectedProduct = yearly
            }
        }
        .alert(L("error"), isPresented: .init(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button(L("ok")) { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
        .confirmationDialog(L("sign_out"), isPresented: $showSignOutConfirmation) {
            Button(L("sign_out"), role: .destructive) {
                try? authManager.signOut()
            }
            Button(L("cancel"), role: .cancel) {}
        } message: {
            Text(L("sign_out_confirm"))
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if !isDismissible {
                Button {
                    showSignOutConfirmation = true
                } label: {
                    Text(L("sign_out"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            if isDismissible {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Milo icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.6), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(L("meet_milo"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Text(L("your_ai_assistant"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        HStack(spacing: 20) {
            FeatureItem(icon: "doc.text.viewfinder", label: L("feature_scan"))
            FeatureItem(icon: "chart.bar.fill", label: L("feature_analyze"))
            FeatureItem(icon: "heart.fill", label: L("feature_health"))
            FeatureItem(icon: "bubble.left.fill", label: L("feature_chat"))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 10) {
            // Yearly
            if let yearly = subscriptionManager.yearlyProduct {
                CompactPricingCard(
                    title: L("yearly"),
                    price: yearly.displayPrice,
                    period: "year",
                    weeklyPrice: subscriptionManager.weeklyPrice(for: yearly),
                    badge: L("best_value"),
                    messageLimit: "\(RateLimitConfig.defaultMessagesPerMonth) AI messages/month",
                    isSelected: selectedProduct?.id == yearly.id
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedProduct = yearly
                    }
                }
            }

            // Monthly
            if let monthly = subscriptionManager.monthlyProduct {
                CompactPricingCard(
                    title: L("monthly"),
                    price: monthly.displayPrice,
                    period: "month",
                    weeklyPrice: subscriptionManager.weeklyPrice(for: monthly),
                    badge: nil,
                    messageLimit: "\(RateLimitConfig.defaultMessagesPerMonth) AI messages/month",
                    isSelected: selectedProduct?.id == monthly.id
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedProduct = monthly
                    }
                }
            }

            // Loading
            if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
                ProgressView()
                    .padding(20)
            }
        }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        } label: {
            HStack {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "gift.fill")
                    Text(L("start_free_trial"))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
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

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text(L("restore_purchases"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 12) {
                Link(L("terms"), destination: URL(string: "https://scandalicious.app/terms")!)
                Text("•")
                Link(L("privacy"), destination: URL(string: "https://scandalicious.app/privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))

            Text(L("cancel_anytime"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showSuccessAnimation)

                Text(L("welcome_success"))
                    .font(.title)
                    .fontWeight(.bold)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Feature Item

struct FeatureItem: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Pricing Card

struct CompactPricingCard: View {
    let title: String
    let price: String
    let period: String
    let weeklyPrice: String
    let badge: String?
    let messageLimit: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.purple : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 14, height: 14)
                    }
                }

                // Plan info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(weeklyPrice)/week")
                            .font(.caption)
                            .foregroundStyle(.purple)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))

                        Text(messageLimit)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 0) {
                    Text(price)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("/\(period)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(isSelected ? 0.12 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? Color.purple : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}

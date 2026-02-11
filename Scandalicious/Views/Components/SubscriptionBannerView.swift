//
//  SubscriptionBannerView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import SwiftUI
import StoreKit

/// A compact banner to show subscription status and prompt upgrades
struct SubscriptionBannerView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        Group {
            if !subscriptionManager.subscriptionStatus.isActive {
                upgradePromptBanner
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var upgradePromptBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Premium")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Start your 14-day free trial")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Try Free")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding()
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// A minimal inline upgrade button for use in toolbars or compact spaces
struct SubscriptionInlineButton: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        Group {
            if !subscriptionManager.subscriptionStatus.isActive {
                Button {
                    showPaywall = true
                } label: {
                    Label("Pro", systemImage: "crown.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
            }
        }
    }
}

/// Status card showing current subscription details
struct SubscriptionStatusCard: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false

    var body: some View {
        VStack(spacing: 16) {
            if subscriptionManager.subscriptionStatus.isActive {
                activeSubscriptionCard
            } else {
                inactiveSubscriptionCard
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    private var activeSubscriptionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)

                Text("Premium Active")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            HStack {
                Text(subscriptionManager.subscriptionStatus.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Manage") {
                    showManageSubscriptions = true
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var inactiveSubscriptionCard: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)

                    Text("Upgrade to Premium")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Unlock all features with a free trial")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
            .padding()
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Feature Gate

/// View modifier to gate premium features behind subscription
struct PremiumFeatureGate: ViewModifier {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: subscriptionManager.subscriptionStatus.isActive ? 0 : blurRadius)
                .disabled(!subscriptionManager.subscriptionStatus.isActive)

            if !subscriptionManager.subscriptionStatus.isActive {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Premium Feature")
                        .font(.headline)

                    Button {
                        showPaywall = true
                    } label: {
                        Text("Unlock")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

extension View {
    /// Gates this view behind a premium subscription
    /// - Parameter blurRadius: How much to blur the content (default: 10)
    func premiumGated(blurRadius: CGFloat = 10) -> some View {
        modifier(PremiumFeatureGate(blurRadius: blurRadius))
    }
}

// MARK: - Previews

#Preview("Banner") {
    VStack {
        Spacer()
        SubscriptionBannerView()
            .padding()
        Spacer()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Status Card") {
    VStack {
        SubscriptionStatusCard()
            .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Inline Button") {
    HStack {
        Text("Settings")
        Spacer()
        SubscriptionInlineButton()
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}

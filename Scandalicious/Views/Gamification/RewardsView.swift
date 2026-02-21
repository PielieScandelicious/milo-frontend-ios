//
//  RewardsView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct RewardsView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var showSpinWheel = false
    @State private var showBadgeUnlock = false
    @State private var badgeToShow: Badge? = nil
    @State private var appeared = false

    private let brandPurple = Color(red: 0.45, green: 0.15, blue: 0.85)
    private let headerGoldColor = Color(red: 0.18, green: 0.14, blue: 0.05)

    var body: some View {
        ZStack(alignment: .top) {
            Color(white: 0.05).ignoresSafeArea()

            // Gold gradient header
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: headerGoldColor, location: 0.0),
                        .init(color: headerGoldColor.opacity(0.6), location: 0.3),
                        .init(color: Color(red: 0.12, green: 0.09, blue: 0.03).opacity(0.25), location: 0.55),
                        .init(color: Color.clear, location: 0.8)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.45 + geo.safeAreaInsets.top)
                .offset(y: -geo.safeAreaInsets.top)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero wallet card
                    WalletCardView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Spins card
                    spinsCard
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Streak card
                    StreakCardView(streak: gm.streak)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Tier card
                    TierProgressView(tierProgress: gm.tierProgress)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Coupon store
                    CouponStoreView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // My coupons
                    if !gm.ownedCoupons.isEmpty {
                        MyCouponsView()
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                    }

                    // Badges
                    BadgeGridView(badges: gm.badges)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Spacer().frame(height: 100)
                }
                .padding(.top, 20)
            }

            // Badge unlock overlay
            if showBadgeUnlock, let badge = badgeToShow {
                BadgeUnlockView(badge: badge) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showBadgeUnlock = false
                    }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSpinWheel) {
            SpinWheelView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .badgeUnlocked)) { _ in
            if let badge = gm.lastUnlockedBadge {
                badgeToShow = badge
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showBadgeUnlock = true
                }
            }
        }
    }

    // MARK: - Spins Card

    private var spinsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FREE SPINS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(gm.spinsAvailable)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gm.spinsAvailable)
                    Text("available")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer()
            Button {
                showSpinWheel = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("SPIN NOW")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                gm.spinsAvailable > 0
                                    ? LinearGradient(colors: [Color(red: 0.55, green: 0.2, blue: 0.95),
                                                               Color(red: 0.35, green: 0.1, blue: 0.65)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color(white: 0.2), Color(white: 0.15)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: Color(red: 0.45, green: 0.15, blue: 0.85).opacity(
                                gm.spinsAvailable > 0 ? 0.5 : 0), radius: 12, y: 6)
                    )
            }
            .disabled(gm.spinsAvailable == 0)
            .opacity(gm.spinsAvailable == 0 ? 0.5 : 1.0)
        }
        .padding(20)
        .glassCard()
    }
}

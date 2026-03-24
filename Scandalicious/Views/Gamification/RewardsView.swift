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
    @State private var appeared = false
    @State private var contentOpacity: Double = 0
    @State private var showBadgeTestMode = false

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

                    // Referral card
                    ReferralCardView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Withdraw cash
                    WithdrawCardView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Badges
                    BadgeGridView(badges: gm.badges)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Badge test mode
                    if gm.badgeTestMode {
                        badgeTestPanel
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, 20)
            }

        }
        .navigationBarHidden(true)
        .opacity(contentOpacity)
        .sheet(isPresented: $showSpinWheel) {
            SpinWheelView()
        }
        .sheet(isPresented: $showBadgeTestMode) {
            BadgeTestModeSheet()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
            gm.fetchAndSyncWallet()
        }
    }

    // MARK: - Spins Card

    private var spinsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SPIN THE WHEEL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))
                Text("Try your luck")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
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
                                LinearGradient(
                                    colors: [Color(red: 0.55, green: 0.2, blue: 0.95),
                                             Color(red: 0.35, green: 0.1, blue: 0.65)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(red: 0.45, green: 0.15, blue: 0.85).opacity(0.5), radius: 12, y: 6)
                    )
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Badge Test Panel (inline)

    private var badgeTestPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "ant.fill")
                    .foregroundStyle(.green)
                Text("Badge Test Mode")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
                Spacer()
                Button("Full Panel") {
                    showBadgeTestMode = true
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
            }

            HStack(spacing: 10) {
                Button {
                    gm.testUnlockNextBadge()
                } label: {
                    Label("Unlock Next", systemImage: "lock.open.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.green))
                }

                Button {
                    gm.testUnlockAllBadges()
                } label: {
                    Label("Unlock All", systemImage: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(red: 1.0, green: 0.84, blue: 0.0)))
                }

                Button {
                    gm.testResetAllBadges()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(white: 0.2)))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Badge Test Mode Sheet

struct BadgeTestModeSheet: View {
    @ObservedObject private var gm = GamificationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Badge Test Mode", isOn: $gm.badgeTestMode)
                        .tint(.green)
                } header: {
                    Text("Test Mode")
                } footer: {
                    Text("Enable to show inline test controls on the Rewards screen.")
                }

                Section("Quick Actions") {
                    Button {
                        gm.testUnlockNextBadge()
                    } label: {
                        Label("Unlock Next Locked Badge", systemImage: "lock.open.fill")
                    }

                    Button {
                        gm.testUnlockAllBadges()
                    } label: {
                        Label("Unlock All Badges", systemImage: "star.fill")
                    }

                    Button(role: .destructive) {
                        gm.testResetAllBadges()
                    } label: {
                        Label("Reset All Badges", systemImage: "arrow.counterclockwise")
                    }
                }

                Section("Individual Badges") {
                    ForEach(gm.badges) { badge in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(badge.isUnlocked ? badge.iconColor.color.opacity(0.15) : Color(white: 0.08))
                                    .frame(width: 40, height: 40)
                                Image(systemName: badge.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(badge.isUnlocked ? badge.iconColor.color : Color(white: 0.3))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(badge.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(badge.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                            Spacer()

                            if badge.isUnlocked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Unlock") {
                                    gm.testUnlockBadge(id: badge.id)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().stroke(.green, lineWidth: 1))
                            }
                        }
                        .listRowBackground(Color(white: 0.08))
                    }
                }

                Section("Badge Stats") {
                    statRow("Total Receipts", value: "\(gm.totalReceiptCount)")
                    statRow("Total Spins", value: "\(gm.totalSpinCount)")
                    statRow("Unique Stores", value: "\(gm.uniqueStores.count)")
                    statRow("Unique Categories", value: "\(gm.uniqueCategories.count)")
                    statRow("Grocery Receipts", value: "\(gm.groceryReceiptCount)")
                    statRow("Referrals", value: "\(gm.referralCount)")
                }

                Section("Simulate Events") {
                    Button {
                        gm.checkReceiptBadges(
                            storeName: "Test Store \(Int.random(in: 1...10))",
                            receiptAmount: 150,
                            categories: ["Groceries"],
                            uploadDate: Date()
                        )
                    } label: {
                        Label("Simulate Receipt (€150 Grocery)", systemImage: "doc.text.viewfinder")
                    }

                    Button {
                        gm.checkReceiptBadges(
                            storeName: "Night Store",
                            receiptAmount: 25,
                            categories: ["Shopping"],
                            uploadDate: Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
                        )
                    } label: {
                        Label("Simulate Night Scan (11 PM)", systemImage: "moon.fill")
                    }

                    Button {
                        // Simulate Saturday scan
                        let cal = Calendar.current
                        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
                        comps.weekday = 7 // Saturday
                        let saturday = cal.date(from: comps) ?? Date()
                        gm.checkReceiptBadges(storeName: "Weekend Store", receiptAmount: 30, categories: ["Shopping"], uploadDate: saturday)
                        // Then Sunday
                        comps.weekday = 1
                        let sunday = cal.date(from: comps) ?? Date()
                        gm.checkReceiptBadges(storeName: "Weekend Store", receiptAmount: 20, categories: ["Shopping"], uploadDate: sunday)
                    } label: {
                        Label("Simulate Weekend Warrior", systemImage: "sun.max.fill")
                    }

                    Button {
                        gm.checkBudgetBadges(spentRatio: 0.75)
                    } label: {
                        Label("Simulate Under Budget (75%)", systemImage: "chart.pie.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.05))
            .navigationTitle("Badge Test Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .listRowBackground(Color(white: 0.08))
    }
}

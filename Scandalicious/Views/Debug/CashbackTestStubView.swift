//
//  CashbackTestStubView.swift
//  Scandalicious
//
//  DEBUG-only sheet for testing all cashback reward scenarios and limits
//  without needing real receipts or a live backend.
//
//  Access: Settings gear → "Test Cashback Rewards" (only appears in DEBUG builds)
//

#if DEBUG

import SwiftUI

// MARK: - Scenario Definition

private struct CashbackScenario: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let apply: (HomeViewModel) -> Void
}

// MARK: - Test Stub View

struct CashbackTestStubView: View {
    var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    private let scenarios: [CashbackScenario] = Self.buildScenarios()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    infoRow
                }

                Section("Tiers") {
                    ForEach(scenarios.filter { $0.subtitle.hasPrefix("Tier") }) { scenario in
                        scenarioRow(scenario)
                    }
                }

                Section("Grote Kar Bonus (≥ €75)") {
                    ForEach(scenarios.filter { $0.subtitle.hasPrefix("Grote Kar") }) { scenario in
                        scenarioRow(scenario)
                    }
                }

                Section("Kickstart (eerste 3 tickets)") {
                    ForEach(scenarios.filter { $0.subtitle.hasPrefix("Kickstart") }) { scenario in
                        scenarioRow(scenario)
                    }
                }

                Section("Fair-Use Limieten") {
                    ForEach(scenarios.filter { $0.subtitle.hasPrefix("Limiet") }) { scenario in
                        scenarioRow(scenario)
                    }
                }

                Section("Streak Rewards") {
                    ForEach(scenarios.filter { $0.subtitle.hasPrefix("Streak") }) { scenario in
                        scenarioRow(scenario)
                    }
                }
            }
            .navigationTitle("Cashback Test Stub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
    }

    // MARK: - Rows

    private var infoRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "flask.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tik een scenario aan om de CashbackRevealOverlay te activeren met gesimuleerde data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func scenarioRow(_ scenario: CashbackScenario) -> some View {
        Button {
            applyAndDismiss(scenario)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(scenario.iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: scenario.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(scenario.iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(scenario.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(scenario.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply

    private func applyAndDismiss(_ scenario: CashbackScenario) {
        dismiss()
        // Small delay so the sheet dismiss animation completes first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            scenario.apply(viewModel)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                viewModel.showCashbackReveal = true
            }
        }
    }

    // MARK: - Scenario Definitions

    // swiftlint:disable function_body_length
    private static func buildScenarios() -> [CashbackScenario] {
        [
            // ── TIERS ────────────────────────────────────────────────────────────

            CashbackScenario(
                title: "Brons – Normaal ticket",
                subtitle: "Tier: 1 Standaard Spin (EV 100 ptn)",
                icon: "medal.fill",
                iconColor: Color(red: 0.80, green: 0.50, blue: 0.20)
            ) { vm in
                vm.setMock(store: "Delhaize", amount: 35.60,
                           points: 100, fixed: 0, groteKar: 0, kickstart: 0,
                           spin: .standard, isKickstart: false, isStreakSaver: false,
                           isGold: false)
            },

            CashbackScenario(
                title: "Zilver – Normaal ticket",
                subtitle: "Tier: 1 Standaard Spin + 75 vaste ptn (175 totaal)",
                icon: "medal.fill",
                iconColor: Color(white: 0.70)
            ) { vm in
                vm.setMock(store: "Colruyt", amount: 52.10,
                           points: 175, fixed: 75, groteKar: 0, kickstart: 0,
                           spin: .standard, isKickstart: false, isStreakSaver: false,
                           isGold: false)
            },

            CashbackScenario(
                title: "Goud – Normaal ticket",
                subtitle: "Tier: 1 Premium Spin (EV 200 ptn)",
                icon: "crown.fill",
                iconColor: Color(red: 1.0, green: 0.84, blue: 0.0)
            ) { vm in
                vm.setMock(store: "Albert Heijn", amount: 48.90,
                           points: 200, fixed: 0, groteKar: 0, kickstart: 0,
                           spin: .premium, isKickstart: false, isStreakSaver: false,
                           isGold: true)
            },

            // ── GROTE KAR ────────────────────────────────────────────────────────

            CashbackScenario(
                title: "Brons – Grote Kar €75 (1 schijf)",
                subtitle: "Grote Kar: Standaard Spin + 50 ptn bonus",
                icon: "cart.fill",
                iconColor: Color(red: 0.80, green: 0.50, blue: 0.20)
            ) { vm in
                vm.setMock(store: "Lidl", amount: 82.45,
                           points: 150, fixed: 0, groteKar: 50, kickstart: 0,
                           spin: .standard, isKickstart: false, isStreakSaver: false,
                           isGold: false)
            },

            CashbackScenario(
                title: "Zilver – Grote Kar €150 (2 schijven)",
                subtitle: "Grote Kar: Standaard Spin + 75 vaste + 100 bonus + 25 extra",
                icon: "cart.fill",
                iconColor: Color(white: 0.70)
            ) { vm in
                vm.setMock(store: "Carrefour", amount: 157.30,
                           points: 300, fixed: 75, groteKar: 125, kickstart: 0,
                           spin: .standard, isKickstart: false, isStreakSaver: false,
                           isGold: false)
            },

            CashbackScenario(
                title: "Goud – Grote Kar €75 (1 schijf)",
                subtitle: "Grote Kar: Premium Spin + 50 schijf + 50 extra = 300 ptn",
                icon: "cart.fill",
                iconColor: Color(red: 1.0, green: 0.84, blue: 0.0)
            ) { vm in
                vm.setMock(store: "Aldi", amount: 91.20,
                           points: 300, fixed: 0, groteKar: 100, kickstart: 0,
                           spin: .premium, isKickstart: false, isStreakSaver: false,
                           isGold: true)
            },

            CashbackScenario(
                title: "Goud – Grote Kar €300+ (max cap, 4 schijven)",
                subtitle: "Grote Kar: Premium Spin + 200 schijven + 50 extra = 450 ptn",
                icon: "cart.badge.plus",
                iconColor: Color(red: 1.0, green: 0.84, blue: 0.0)
            ) { vm in
                vm.setMock(store: "Spar", amount: 320.00,
                           points: 450, fixed: 0, groteKar: 250, kickstart: 0,
                           spin: .premium, isKickstart: false, isStreakSaver: false,
                           isGold: true)
            },

            // ── KICKSTART ────────────────────────────────────────────────────────

            CashbackScenario(
                title: "Kickstart – Ticket 1 (Aha!-ervaring)",
                subtitle: "Kickstart: 500 vaste ptn + 1 Premium Spin",
                icon: "gift.fill",
                iconColor: Color(red: 0.35, green: 0.65, blue: 1.0)
            ) { vm in
                vm.setMock(store: "Delhaize", amount: 28.50,
                           points: 700, fixed: 0, groteKar: 0, kickstart: 500,
                           spin: .premium, isKickstart: true, isStreakSaver: false,
                           isGold: false)
            },

            CashbackScenario(
                title: "Kickstart – Ticket 2 (Bevestiging)",
                subtitle: "Kickstart: 500 vaste ptn + ticketwaarde",
                icon: "gift.fill",
                iconColor: Color(red: 0.35, green: 0.65, blue: 1.0)
            ) { vm in
                vm.setMock(store: "Colruyt", amount: 45.10,
                           points: 600, fixed: 0, groteKar: 0, kickstart: 500,
                           spin: .standard, isKickstart: true, isStreakSaver: false,
                           isGold: false)
            },

            CashbackScenario(
                title: "Kickstart – Ticket 3 (Gewoonte, laatste)",
                subtitle: "Kickstart: 500 vaste ptn + ticketwaarde. Kickstart voltooid!",
                icon: "gift.fill",
                iconColor: Color(red: 0.35, green: 0.65, blue: 1.0)
            ) { vm in
                vm.setMock(store: "Lidl", amount: 38.75,
                           points: 600, fixed: 0, groteKar: 0, kickstart: 500,
                           spin: .standard, isKickstart: true, isStreakSaver: false,
                           isGold: false)
            },

            // ── FAIR-USE LIMIETEN ────────────────────────────────────────────────

            CashbackScenario(
                title: "Streak Saver (ticket 16+)",
                subtitle: "Limiet: Maandlimiet bereikt, 10 symbolische ptn",
                icon: "shield.fill",
                iconColor: Color(red: 0.0, green: 0.8, blue: 0.7)
            ) { vm in
                vm.setMock(store: "Aldi", amount: 22.00,
                           points: 10, fixed: 10, groteKar: 0, kickstart: 0,
                           spin: nil, isKickstart: false, isStreakSaver: true,
                           isGold: true)
            },

            CashbackScenario(
                title: "Grote Kar – Maandlimiet (6x bereikt)",
                subtitle: "Limiet: Grote Kar limiet van 6/maand bereikt, geen bonus",
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange
            ) { vm in
                // Grote Kar ticket maar groteKarPoints = 0 wegens cap
                vm.setMock(store: "Carrefour", amount: 95.00,
                           points: 200, fixed: 0, groteKar: 0, kickstart: 0,
                           spin: .premium, isKickstart: false, isStreakSaver: false,
                           isGold: true)
            },

            // ── STREAK REWARDS ───────────────────────────────────────────────────

            CashbackScenario(
                title: "Streak Level 1 – Week 3 beloning",
                subtitle: "Streak: +150 vaste ptn op normaal ticket",
                icon: "flame.fill",
                iconColor: .orange
            ) { vm in
                vm.setMock(store: "Albert Heijn", amount: 44.30,
                           points: 325, fixed: 150, groteKar: 0, kickstart: 0,
                           spin: .standard, isKickstart: false, isStreakSaver: false,
                           isGold: false)
            },

            CashbackScenario(
                title: "Streak Level 2 – Week 4 Climax",
                subtitle: "Streak: 1 Premium Spin + 200 vaste ptn (EV 400 ptn)",
                icon: "crown.fill",
                iconColor: Color(red: 1.0, green: 0.5, blue: 0.0)
            ) { vm in
                vm.setMock(store: "Delhaize", amount: 67.80,
                           points: 600, fixed: 200, groteKar: 0, kickstart: 0,
                           spin: .premium, isKickstart: false, isStreakSaver: false,
                           isGold: true)
            },
        ]
    }
    // swiftlint:enable function_body_length
}

// MARK: - HomeViewModel Stub Helper

private extension HomeViewModel {
    /// Populates all overlay fields with test data, injects a RecentReceipt,
    /// and credits points + spins to the local wallet — no backend call needed.
    func setMock(
        store: String,
        amount: Double,
        points: Int,
        fixed: Int,
        groteKar: Int,
        kickstart: Int,
        spin: SpinWheelType?,
        isKickstart: Bool,
        isStreakSaver: Bool,
        isGold: Bool
    ) {
        // ── Overlay fields ──────────────────────────────────────────────────
        processingStoreName   = store
        processingAmount      = amount
        pointsTotal           = points
        fixedPoints           = fixed
        groteKarPoints        = groteKar
        kickstartBonusPoints  = kickstart
        spinType              = spin
        self.isKickstart      = isKickstart
        self.isStreakSaver    = isStreakSaver
        isGoldTier            = isGold
        spinsAwarded          = spin != nil ? 1 : 0
        cashbackAmount        = Double(points) / 1000.0
        animatedCashbackValue = 0
        animatedPointsValue   = 0
        showConfetti          = false
        claimingReceiptId     = nil

        // Derive tier for the overlay label (fixes "Goud bonus" shown for Silver)
        if isGold {
            displayTierLevel = .gold
        } else if fixed > 0 {
            displayTierLevel = .silver
        } else {
            displayTierLevel = .bronze
        }

        // ── Store color ─────────────────────────────────────────────────────
        let storeColor: Color
        if let matched = GroceryStore.allCases.first(where: {
            store.localizedCaseInsensitiveContains($0.displayName)
        }) {
            storeColor = matched.accentColor
        } else {
            storeColor = .white
        }
        processingStoreColor = storeColor

        // ── Inject into Recent Rewards list ─────────────────────────────────
        let mockReceipt = RecentReceipt(
            id: UUID().uuidString,
            storeName: isKickstart ? "Kickstart Bonus" : store.localizedCapitalized,
            storeColor: isKickstart ? Color(red: 0.35, green: 0.65, blue: 1.0) : storeColor,
            totalAmount: amount,
            cashbackAmount: Double(points) / 1000.0,
            spinsAwarded: spin != nil ? 1 : 0,
            date: Date(),
            isReferralReward: false,
            isStreakReward: false
        )
        recentReceipts.insert(mockReceipt, at: 0)

        // ── Credit wallet & spins locally ───────────────────────────────────
        let stdSpins = spin == .standard ? 1 : 0
        let prmSpins = spin == .premium  ? 1 : 0
        GamificationManager.shared.injectTestReward(
            points: points,
            standardSpins: stdSpins,
            premiumSpins: prmSpins
        )
    }
}

// MARK: - Preview

#Preview("Cashback Test Stub") {
    CashbackTestStubView(viewModel: HomeViewModel())
}

#endif

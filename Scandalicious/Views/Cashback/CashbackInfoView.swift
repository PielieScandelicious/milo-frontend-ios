//
//  CashbackInfoView.swift
//  Scandalicious
//
//  Premium sleek overview of the Milo cashback & rewards system.
//

import SwiftUI

struct CashbackInfoView: View {
    @Environment(\.dismiss) private var dismiss

    private let deepPurple   = Color(red: 0.35, green: 0.10, blue: 0.60)
    private let accentPurple = Color(red: 0.55, green: 0.20, blue: 0.85)
    private let gold         = Color(red: 1.00, green: 0.84, blue: 0.00)
    private let teal         = Color(red: 0.20, green: 0.85, blue: 0.70)

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 32)
                        .padding(.bottom, 28)

                    // Conversion pill
                    conversionPill
                        .padding(.bottom, 28)

                    // Sections
                    VStack(spacing: 20) {
                        spinWheelsSection
                        tierSection
                        streakSection
                        fairUseSection
                        kickstartSection
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 48)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(white: 0.05)
            LinearGradient(
                colors: [deepPurple.opacity(0.55), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentPurple, deepPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .shadow(color: accentPurple.opacity(0.5), radius: 18, y: 8)

                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(gold)
            }

            Text("Cashback Rewards")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Earn Milo Points every time you scan a receipt.\nRedeem for real cash.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Conversion Pill

    private var conversionPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(gold)
            Text("10,000 pts = €10.00")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("·")
                .foregroundStyle(.white.opacity(0.3))
            Text("Min. payout €10")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Spin Wheels

    private var spinWheelsSection: some View {
        InfoCard(title: "Spin Wheels", icon: "circle.grid.2x2.fill", iconColor: teal) {
            VStack(spacing: 12) {
                SpinRow(
                    label: "Standard Spin",
                    value: "~100 pts",
                    valueColor: .white.opacity(0.8),
                    note: "Earned each Bronze/Silver receipt"
                )
                Divider().background(Color.white.opacity(0.08))
                SpinRow(
                    label: "Premium Spin",
                    value: "~200 pts",
                    valueColor: gold,
                    note: "Earned each Gold receipt"
                )
                Divider().background(Color.white.opacity(0.08))
                SpinRow(
                    label: "Grote Kar Bonus",
                    value: "+50 pts / €75",
                    valueColor: teal,
                    note: "Receipts ≥ €75 · capped at €300 · max 6×/month"
                )
            }
        }
    }

    // MARK: - Tier System

    private var tierSection: some View {
        InfoCard(title: "Monthly Tiers", icon: "trophy.fill", iconColor: gold) {
            VStack(spacing: 12) {
                TierRow(tier: "Bronze", condition: "< 4 receipts/month",  reward: "1 Standard Spin",         color: Color(red: 0.80, green: 0.55, blue: 0.30))
                Divider().background(Color.white.opacity(0.08))
                TierRow(tier: "Silver", condition: "4–9 receipts/month",  reward: "1 Standard Spin + 75 pts", color: Color(white: 0.70))
                Divider().background(Color.white.opacity(0.08))
                TierRow(tier: "Gold",   condition: "10+ receipts/month",  reward: "1 Premium Spin",           color: gold)
            }

            Text("Your scan count this month sets your tier for next month.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 6)
        }
    }

    // MARK: - Streak Rewards

    private var streakSection: some View {
        InfoCard(title: "Weekly Streaks", icon: "flame.fill", iconColor: Color(red: 1.0, green: 0.45, blue: 0.15)) {
            VStack(alignment: .leading, spacing: 14) {
                StreakBlock(
                    title: "Month 1 — Standard Streak",
                    subtitle: "Total expected value: ~500 pts",
                    weeks: [
                        (week: "Week 1", reward: "No bonus (start)"),
                        (week: "Week 2", reward: "+1 Standard Spin (~100 pts)"),
                        (week: "Week 3", reward: "+150 fixed pts"),
                        (week: "Week 4", reward: "+1 Premium Spin + 50 pts (~250 pts)"),
                    ]
                )

                Divider().background(Color.white.opacity(0.08))

                StreakBlock(
                    title: "Month 2+ — Continuous Streak",
                    subtitle: "Total expected value: ~1,000 pts",
                    weeks: [
                        (week: "Week 1", reward: "+150 loyalty pts"),
                        (week: "Week 2", reward: "+1 Standard Spin + 100 pts"),
                        (week: "Week 3", reward: "+1 Standard Spin + 150 pts"),
                        (week: "Week 4", reward: "+1 Premium Spin + 200 pts (~400 pts)"),
                    ]
                )

                Text("Miss one week? You drop back to Month 1, Week 1.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Fair Use Caps

    private var fairUseSection: some View {
        InfoCard(title: "Fair Use Limits", icon: "checkmark.shield.fill", iconColor: teal) {
            VStack(spacing: 10) {
                CapRow(icon: "sun.max",   label: "Daily",   value: "2 receipts per supermarket chain")
                CapRow(icon: "calendar.badge.clock", label: "Weekly",  value: "5 receipts per week")
                CapRow(icon: "calendar",  label: "Monthly", value: "15 receipts per month")
                CapRow(icon: "cart.fill", label: "Grote Kar", value: "6 bonus receipts per month")

                Divider().background(Color.white.opacity(0.08))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(gold)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Streak Saver")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Receipts beyond #15 still count toward streaks & tiers, earning 10 symbolic pts each.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    // MARK: - Kickstart

    private var kickstartSection: some View {
        InfoCard(title: "Kickstart Welcome Bonus", icon: "gift.fill", iconColor: accentPurple) {
            VStack(spacing: 12) {
                KickstartRow(number: 1, reward: "+500 pts + 1 Premium Spin", label: "The \"Aha!\" moment")
                KickstartRow(number: 2, reward: "+500 pts",                  label: "The confirmation")
                KickstartRow(number: 3, reward: "+500 pts",                  label: "The habit — Kickstart done!")
            }
            Text("New users earn ~€1.70 in points just by scanning their first 3 receipts.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 6)
        }
    }
}

// MARK: - Reusable Sub-components

private struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }
}

private struct SpinRow: View {
    let label: String
    let value: String
    let valueColor: Color
    let note: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }
}

private struct TierRow: View {
    let tier: String
    let condition: String
    let reward: String
    let color: Color

    var body: some View {
        HStack(alignment: .top) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                    Text(condition)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            Text(reward)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 160, alignment: .trailing)
        }
    }
}

private struct StreakBlock: View {
    let title: String
    let subtitle: String
    let weeks: [(week: String, reward: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.38))
            }
            VStack(spacing: 6) {
                ForEach(weeks, id: \.week) { item in
                    HStack {
                        Text(item.week)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 50, alignment: .leading)
                        Text(item.reward)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct CapRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}

private struct KickstartRow: View {
    let number: Int
    let reward: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.55, green: 0.20, blue: 0.85).opacity(0.25))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.75, green: 0.50, blue: 1.00))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reward)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
        }
    }
}

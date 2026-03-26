//
//  CharityCardView.swift
//  Scandalicious
//

import SwiftUI

struct CharityCardView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var showDonateFlow = false
    @State private var showHistory = false
    @State private var isExpanded = false

    private let brandPurple = Color(red: 0.45, green: 0.15, blue: 0.85)

    private var sortedCharities: [CharityItem] {
        gm.charities.sorted { $0.communityTotal > $1.communityTotal }
    }

    private var communityGrandTotal: Double {
        gm.charities.reduce(0) { $0 + $1.communityTotal }
    }

    private var visibleCharities: [CharityItem] {
        isExpanded ? sortedCharities : Array(sortedCharities.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "hands.and.sparkles.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(brandPurple)
                Text("Donate to a Charity")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if !gm.charityHistory.isEmpty {
                    Button { showHistory = true } label: {
                        Text("History")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            if gm.charities.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(.white.opacity(0.4))
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                charityContent
            }
        }
        .padding(16)
        .glassCard()
        .sheet(isPresented: $showDonateFlow) {
            CharityDonateFlowView()
                .onDisappear {
                    gm.fetchCharities()
                    gm.fetchCharityHistory()
                }
        }
        .sheet(isPresented: $showHistory) {
            CharityDonationHistoryView()
        }
        .onAppear {
            gm.fetchCharities()
            gm.fetchCharityHistory()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var charityContent: some View {
        let goal = 1000.0

        // Community total strip
        communityTotalStrip

        // Charity rows
        VStack(spacing: 8) {
            ForEach(visibleCharities) { charity in
                charityRow(charity: charity, maxTotal: goal)
            }

            // Expand / collapse toggle
            if gm.charities.count > 3 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded
                             ? "Show less"
                             : "+ \(gm.charities.count - 3) more charities")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(brandPurple.opacity(0.8))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(brandPurple.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }

        // Recent donation feedback
        if let recent = gm.charityHistory.first {
            recentDonationChip(recent)
        }

        // Footer: personal total or nudge text
        HStack {
            if gm.charityTotalDonated > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(brandPurple)
                    Text("Your total: \(String(format: "€%.2f", gm.charityTotalDonated))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Text("Support a Belgian charity with your rewards")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
        }

        // CTA
        Button {
            showDonateFlow = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("DONATE")
                    .font(.system(size: 15, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [brandPurple, Color(red: 0.6, green: 0.2, blue: 1.0)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: brandPurple.opacity(0.4), radius: 10, y: 5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Community Total Strip

    private var communityTotalStrip: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "€%.0f", communityGrandTotal))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("raised by the community")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(totalDonationCount)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("total donations")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(brandPurple.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(brandPurple.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // Sum of donation counts across charities (derived from community totals at €5 min)
    private var totalDonationCount: String {
        let count = gm.charities.reduce(0.0) { $0 + $1.communityTotal } / 5.0
        return count >= 1000
            ? String(format: "%.1fk", count / 1000)
            : "\(Int(count))"
    }

    // MARK: - Recent Donation Chip

    @ViewBuilder
    private func recentDonationChip(_ donation: CharityDonationItem) -> some View {
        let statusColor = donationStatusColor(donation)
        HStack(spacing: 8) {
            Image(systemName: donationStatusIcon(donation))
                .font(.system(size: 13))
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Last donation: \(String(format: "€%.0f", donation.amount)) → \(donation.charityName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Text(donation.statusLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor.opacity(0.9))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func donationStatusIcon(_ donation: CharityDonationItem) -> String {
        switch donation.status {
        case "transferred":    return "checkmark.circle.fill"
        case "pending":        return "clock.fill"
        case "pending_review": return "exclamationmark.circle.fill"
        case "rejected":       return "xmark.circle.fill"
        default:               return "circle.fill"
        }
    }

    private func donationStatusColor(_ donation: CharityDonationItem) -> Color {
        switch donation.status {
        case "transferred":    return Color(red: 0.2, green: 0.78, blue: 0.45)
        case "pending":        return Color(red: 1.0, green: 0.75, blue: 0.0)
        case "pending_review": return Color(red: 1.0, green: 0.58, blue: 0.2)
        case "rejected":       return Color(red: 0.93, green: 0.27, blue: 0.27)
        default:               return Color.white.opacity(0.4)
        }
    }

    // MARK: - Charity Row

    @ViewBuilder
    private func charityRow(charity: CharityItem, maxTotal: Double) -> some View {
        let progress = maxTotal > 0 ? min(charity.communityTotal / maxTotal, 1.0) : 0.0
        let accentColor = charityColor(charity.color)

        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: charity.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(charity.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "€%.0f / €1k", charity.communityTotal))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor.opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                            .animation(.spring(response: 0.6), value: progress)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func charityColor(_ name: String) -> Color {
        switch name {
        case "red":    return Color(red: 0.93, green: 0.27, blue: 0.27)
        case "orange": return Color(red: 0.98, green: 0.58, blue: 0.2)
        case "blue":   return Color(red: 0.24, green: 0.56, blue: 0.96)
        case "green":  return Color(red: 0.2, green: 0.78, blue: 0.45)
        case "purple": return Color(red: 0.55, green: 0.25, blue: 0.9)
        case "yellow": return Color(red: 1.0, green: 0.84, blue: 0.0)
        default:       return Color(red: 0.45, green: 0.15, blue: 0.85)
        }
    }
}

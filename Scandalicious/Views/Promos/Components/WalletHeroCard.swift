//
//  WalletHeroCard.swift
//  Scandalicious
//
//  Hero wallet card that anchors the redesigned Cashback tab. Renders a
//  large serif balance, three lifetime stats (Earned / Pending / This month)
//  and a Withdraw CTA. Also exposes a `compact` variant for the no-match
//  empty state and a `newUser` variant for the €0 first-run state.
//

import SwiftUI

// MARK: - WalletHeroCard

struct WalletHeroCard: View {
    let balanceCents: Int
    let earnedCents: Int
    let pendingCents: Int
    let thisMonthCents: Int
    /// When non-nil, the Withdraw chip renders as a tappable Button. When nil
    /// (the common case where the entire card is wrapped in a NavigationLink)
    /// the chip is decorative so it doesn't intercept the parent tap.
    var onWithdraw: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Top row: balance + Withdraw button
            HStack(alignment: .top) {
                balanceColumn
                Spacer()
                withdrawButton
            }

            // Stats row, separated by 1pt vertical dividers
            HStack(spacing: 0) {
                Stat(label: "Earned",     valueCents: earnedCents,     style: .neutral)
                divider
                Stat(label: "Pending",    valueCents: pendingCents,    style: .warn)
                divider
                Stat(label: "This month", valueCents: thisMonthCents,  style: .accent)
            }
            .padding(.top, 14)
            .padding(.top, 1)               // matches the 1px top border in design
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(CashbackTokens.cardStroke)
                    .frame(height: 1)
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(walletBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CashbackTokens.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Balance

    private var balanceColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR WALLET")
                .font(CashbackFont.sans(10.5, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(CashbackTokens.greenDim)
                .lineLimit(1)
            EuroBalance(cents: balanceCents, color: CashbackTokens.green, size: .large)
        }
    }

    // MARK: Withdraw

    @ViewBuilder
    private var withdrawButton: some View {
        let chip = HStack(spacing: 5) {
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .heavy))
            Text("Withdraw")
                .font(CashbackFont.sans(13, weight: .semibold))
                .kerning(-0.1)
        }
        .foregroundStyle(CashbackTokens.greenInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(CashbackTokens.green))

        if let onWithdraw {
            Button(action: onWithdraw) { chip }
                .buttonStyle(.plain)
        } else {
            chip
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(CashbackTokens.cardStroke)
            .frame(width: 1)
            .padding(.vertical, 2)
    }

    // MARK: Background

    private var walletBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CashbackTokens.green.opacity(0.16),
                    CashbackTokens.green.opacity(0.04),
                    Color.white.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Radial accent in the upper-right
            RadialGradient(
                colors: [CashbackTokens.green.opacity(0.18), .clear],
                center: UnitPoint(x: 0.8, y: 0.2),
                startRadius: 0,
                endRadius: 180
            )
        }
    }
}

// MARK: - Stat cell

private enum StatStyle { case neutral, warn, accent }

private struct Stat: View {
    let label: String
    let valueCents: Int
    let style: StatStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(CashbackFont.sans(10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(CashbackTokens.text45)
                .lineLimit(1)
            Text(MoneyFormatter.eur(cents: valueCents))
                .font(CashbackFont.mono(15, weight: .medium))
                .monospacedDigit()
                .kerning(-0.3)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 14)
    }

    private var color: Color {
        switch style {
        case .neutral: return .white
        case .warn:    return CashbackTokens.warn
        case .accent:  return CashbackTokens.green
        }
    }
}

// MARK: - EuroBalance (serif € + integer + decimals)

struct EuroBalance: View {
    let cents: Int
    var color: Color = CashbackTokens.green
    var size: Size = .large

    enum Size {
        case large    // hero (€24/56/.65 28)
        case compact  // no-match (€16/32/.65 18)
        case empty    // new-user (same shape as large but dim color)

        var euroSize: CGFloat   { switch self { case .large, .empty: 24; case .compact: 16 } }
        var intSize: CGFloat    { switch self { case .large, .empty: 56; case .compact: 32 } }
        var decSize: CGFloat    { switch self { case .large, .empty: 28; case .compact: 18 } }
        var intKern: CGFloat    { switch self { case .large, .empty: -2; case .compact: -1 } }
        var decKern: CGFloat    { switch self { case .large, .empty: -0.8; case .compact: -0.5 } }
    }

    var body: some View {
        let euros = cents / 100
        let dec = abs(cents % 100)
        let decString = String(format: ".%02d", dec)
        return HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("€")
                .font(CashbackFont.serif(size.euroSize))
                .foregroundStyle(color)
                .padding(.trailing, 2)
            Text("\(euros)")
                .font(CashbackFont.serif(size.intSize))
                .monospacedDigit()
                .kerning(size.intKern)
                .foregroundStyle(color)
            Text(decString)
                .font(CashbackFont.serif(size.decSize))
                .monospacedDigit()
                .kerning(size.decKern)
                .foregroundStyle(color)
        }
        .lineLimit(1)
    }
}

// MARK: - WalletCompactCard (no-match empty state header)

struct WalletCompactCard: View {
    let balanceCents: Int
    var onWithdraw: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR WALLET")
                    .font(CashbackFont.sans(10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(CashbackTokens.greenDim)
                EuroBalance(cents: balanceCents, color: CashbackTokens.green, size: .compact)
            }
            Spacer()
            withdrawChip
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    CashbackTokens.green.opacity(0.16),
                    CashbackTokens.green.opacity(0.04),
                    Color.white.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CashbackTokens.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var withdrawChip: some View {
        let chip = HStack(spacing: 5) {
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .heavy))
            Text("Withdraw")
                .font(CashbackFont.sans(13, weight: .semibold))
        }
        .foregroundStyle(CashbackTokens.greenInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(CashbackTokens.green))

        if let onWithdraw {
            Button(action: onWithdraw) { chip }
                .buttonStyle(.plain)
        } else {
            chip
        }
    }
}

// MARK: - WalletEmptyHeroCard (new-user €0 state)

/// Greyed-out hero card with a dashed-disc instead of the Withdraw button and
/// a "Withdraw at €X.XX" threshold preview underneath.
struct WalletEmptyHeroCard: View {
    var thresholdCents: Int = 1000

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR WALLET")
                        .font(CashbackFont.sans(10.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(CashbackTokens.greenDim)
                    EuroBalance(cents: 0, color: CashbackTokens.text40, size: .empty)
                    Text("Claim your first deal to start earning")
                        .font(CashbackFont.sans(12))
                        .kerning(-0.05)
                        .foregroundStyle(CashbackTokens.text55)
                        .padding(.top, 6)
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(
                            CashbackTokens.greenDim,
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(CashbackTokens.greenDim)
                }
                .frame(width: 44, height: 44)
            }

            // Threshold preview
            VStack(spacing: 6) {
                HStack {
                    Text("Withdraw at")
                        .font(CashbackFont.sans(11))
                        .tracking(0.2)
                        .foregroundStyle(CashbackTokens.text55)
                    Spacer()
                    Text(MoneyFormatter.eur(cents: thresholdCents))
                        .font(CashbackFont.mono(13, weight: .medium))
                        .monospacedDigit()
                        .kerning(-0.2)
                        .foregroundStyle(.white)
                }
                Capsule()
                    .fill(CashbackTokens.text08)
                    .frame(height: 4)
            }
            .padding(.top, 14)
            .padding(.top, 1)
            .overlay(alignment: .top) {
                Rectangle().fill(CashbackTokens.cardStroke).frame(height: 1)
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        CashbackTokens.green.opacity(0.10),
                        CashbackTokens.green.opacity(0.02),
                        Color.white.opacity(0.03),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [CashbackTokens.green.opacity(0.14), .clear],
                    center: UnitPoint(x: 0.8, y: 0.2),
                    startRadius: 0, endRadius: 180
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CashbackTokens.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

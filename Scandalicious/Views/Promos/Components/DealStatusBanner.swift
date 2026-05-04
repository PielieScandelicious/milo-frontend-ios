//
//  DealStatusBanner.swift
//  Scandalicious
//
//  Unified, sleek status surface for brand-cashback deals: pending review,
//  denial (with reason), or earned. Two sizes — `.full` for the detail
//  sheet (icon + title + subtitle + optional action) and `.compact` for a
//  capsule ribbon overlay on the grid card. Glass fill, gradient stroke
//  keyed to state colour, animated SF Symbol on the icon.
//
//  Designed to replace fragmented surfaces:
//    • the validity-section pending/denial rows
//    • the 6pt red dot on the grid card
//    • the bottom toast (which now uses this same component)
//

import SwiftUI

// MARK: - State

/// Priority-resolved status the banner renders. Computed from a deal via
/// `BrandCashbackDeal.bannerKind` — earned > denied > pending > nil.
enum DealStatusKind: Equatable {
    case pending
    case denied(reason: String)
    case earned(amountFormatted: String)
}

enum DealStatusSize {
    case full       // detail sheet, ~64pt tall
    case compact    // grid card ribbon, ~26pt tall
}

// MARK: - Banner

struct DealStatusBanner: View {
    let kind: DealStatusKind
    let size: DealStatusSize
    var onDismiss: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        switch size {
        case .full:    fullBanner
        case .compact: compactRibbon
        }
    }

    // MARK: - Full

    private var fullBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            iconBubble(diameter: 36, iconSize: 17)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bannerBackground(cornerRadius: 16))
        .overlay(topHighlight(cornerRadius: 16))
        .overlay(strokeOverlay(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.96)
        .opacity(hasAppeared || reduceMotion ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Compact ribbon

    private var compactRibbon: some View {
        HStack(spacing: 6) {
            iconBubble(diameter: 18, iconSize: 9)
            Text(compactLabel)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(accent.opacity(0.18)))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.65), accent.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: accent.opacity(0.25), radius: 6, y: 2)
    }

    // MARK: - Icon bubble

    @ViewBuilder
    private func iconBubble(diameter: CGFloat, iconSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.18))
            Circle()
                .strokeBorder(accent.opacity(0.35), lineWidth: 0.8)
            symbolView(size: iconSize)
                .foregroundStyle(accent)
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private func symbolView(size: CGFloat) -> some View {
        let img = Image(systemName: iconName)
            .font(.system(size: size, weight: .semibold))

        switch kind {
        case .pending:
            if reduceMotion {
                img
            } else {
                img.symbolEffect(.pulse.byLayer, options: .repeating, isActive: hasAppeared)
            }
        case .denied:
            if reduceMotion {
                img
            } else {
                img.symbolEffect(.bounce, value: hasAppeared)
            }
        case .earned:
            if reduceMotion {
                img
            } else {
                img.symbolEffect(.bounce, value: hasAppeared)
            }
        }
    }

    // MARK: - Backgrounds

    @ViewBuilder
    private func bannerBackground(cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.14), accent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    @ViewBuilder
    private func topHighlight(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), .clear],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 1
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func strokeOverlay(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [accent.opacity(0.55), accent.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Tokens

    private var accent: Color {
        switch kind {
        case .pending:                return DealStatusBanner.warningOrange
        case .denied:                 return DealStatusBanner.denialRed
        case .earned:                 return DealStatusBanner.cashbackGreen
        }
    }

    private var iconName: String {
        switch kind {
        case .pending: return "hourglass.bottomhalf.filled"
        case .denied:  return "xmark.octagon.fill"
        case .earned:  return "checkmark.seal.fill"
        }
    }

    private var title: String {
        switch kind {
        case .pending: return "Receipt under review"
        case .denied:  return "Receipt not eligible"
        case .earned:  return "Cashback earned"
        }
    }

    private var subtitle: String {
        switch kind {
        case .pending:
            return "Usually approved within 24 hours."
        case .denied(let reason):
            return reason
        case .earned(let amount):
            return "\(amount) added to your wallet."
        }
    }

    private var compactLabel: String {
        switch kind {
        case .pending: return "PENDING"
        case .denied:  return "NOT ELIGIBLE"
        case .earned:  return "EARNED"
        }
    }

    // Local copies of the cashback palette so this component is self-contained.
    fileprivate static let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
    fileprivate static let warningOrange = Color(red: 1.00, green: 0.55, blue: 0.20)
    fileprivate static let denialRed     = Color(red: 1.00, green: 0.40, blue: 0.40)
}

// MARK: - Preview

#if DEBUG
#Preview("Deal status banner — all states × both sizes") {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                Text("FULL").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.5))
                DealStatusBanner(kind: .pending, size: .full)
                DealStatusBanner(kind: .denied(reason: "Item is not on the eligible variant list."), size: .full, onDismiss: {})
                DealStatusBanner(kind: .earned(amountFormatted: "€1.00"), size: .full)
            }

            Group {
                Text("COMPACT").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 12) {
                    DealStatusBanner(kind: .pending, size: .compact)
                    DealStatusBanner(kind: .denied(reason: "x"), size: .compact)
                    DealStatusBanner(kind: .earned(amountFormatted: "€1.00"), size: .compact)
                }
            }
        }
        .padding(20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [Color(red: 0.06, green: 0.09, blue: 0.14), Color(red: 0.03, green: 0.04, blue: 0.07)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    )
    .preferredColorScheme(.dark)
}
#endif

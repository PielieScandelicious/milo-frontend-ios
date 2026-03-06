//
//  DigitalReceiptHintCard.swift
//  Scandalicious
//
//  Hint card encouraging users to share digital receipts
//  for cashback rewards.
//

import SwiftUI

struct DigitalReceiptHintCard: View {
    @State private var showInfo = false

    private let accent = Color(red: 0.85, green: 0.2, blue: 0.6)

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 2) {
                        Text("Got a digital receipt?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("*")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent.opacity(0.6))
                    }

                    Text("Earn up to 1% cashback on groceries")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .rotationEffect(.degrees(showInfo ? 180 : 0))
            }
            .padding(16)

            // Expandable info
            if showInfo {
                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    Text("The more you spend, the higher your cashback rate. Your rate increases progressively:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)

                    // Cashback table with Gold Tier spins column
                    VStack(spacing: 0) {
                        cashbackTableRow(spend: "Spend", rate: "Cashback", spins: "Gold Tier", isHeader: true)
                        cashbackTableRow(spend: "\u{20AC}0 \u{2013} \u{20AC}80", rate: "0.50%", spins: "\u{2014}")
                        cashbackTableRow(spend: "\u{20AC}80 \u{2013} \u{20AC}160", rate: "0.60%", spins: "+1 spin")
                        cashbackTableRow(spend: "\u{20AC}160 \u{2013} \u{20AC}240", rate: "0.70%", spins: "+1 spin")
                        cashbackTableRow(spend: "\u{20AC}240 \u{2013} \u{20AC}320", rate: "0.80%", spins: "+1 spin")
                        cashbackTableRow(spend: "\u{20AC}320 \u{2013} \u{20AC}400", rate: "0.90%", spins: "+1 spin")
                        cashbackTableRow(spend: "\u{20AC}400 \u{2013} \u{20AC}500", rate: "1.00%", spins: "+1 spin")
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Each segment earns its own rate \u{2014} e.g. on a \u{20AC}200 receipt, the first \u{20AC}80 earns 0.50%, the next \u{20AC}80 earns 0.60%, and the last \u{20AC}40 earns 0.70%.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.3))
                        .fixedSize(horizontal: false, vertical: true)

                    // Gold Tier section
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 0.5)
                    .padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.88, blue: 0.35), Color(red: 0.80, green: 0.60, blue: 0.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Gold Tier")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("Upload at least one receipt over \u{20AC}50 every 7 days to keep Gold Tier. Gold Tier earns you +1 free spin for each cashback segment from \u{20AC}80+, up to 5 spins (max) at \u{20AC}500.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.3))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showInfo.toggle()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .background(cardBackground)
        .overlay(cardBorder)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showInfo)
    }

    private let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.88, blue: 0.35), Color(red: 0.80, green: 0.60, blue: 0.0)],
        startPoint: .leading,
        endPoint: .trailing
    )

    private let cashbackGradient = LinearGradient(
        colors: [Color(red: 0.2, green: 0.85, blue: 0.7), Color(red: 0.15, green: 0.55, blue: 0.75)],
        startPoint: .leading,
        endPoint: .trailing
    )

    private func cashbackTableRow(spend: String, rate: String, spins: String = "", isHeader: Bool = false) -> some View {
        HStack {
            Text(spend)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(rate)
                .frame(width: 55, alignment: .trailing)
                .foregroundStyle(
                    isHeader
                        ? AnyShapeStyle(.white.opacity(0.5))
                        : AnyShapeStyle(cashbackGradient)
                )
            Text(spins)
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(
                    isHeader
                        ? AnyShapeStyle(.white.opacity(0.5))
                        : (spins.hasPrefix("+") ? AnyShapeStyle(goldGradient) : AnyShapeStyle(.white.opacity(0.2)))
                )
        }
        .font(.system(size: 11, weight: isHeader ? .semibold : .regular))
        .foregroundStyle(.white.opacity(isHeader ? 0.5 : 0.35))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isHeader ? 0.06 : 0.03))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(white: 0.08))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
}

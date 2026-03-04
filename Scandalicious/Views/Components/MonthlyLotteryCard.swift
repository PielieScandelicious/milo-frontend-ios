//
//  MonthlyLotteryCard.swift
//  Scandalicious
//
//  Card promoting the monthly lottery with expandable
//  eligibility information via an asterisk indicator.
//

import SwiftUI

struct MonthlyLotteryCard: View {
    @State private var showEligibility = false

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(gold.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "gift.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(gold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 2) {
                        Text("Monthly Lottery")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showEligibility.toggle()
                            }
                        } label: {
                            Text("*")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(gold.opacity(0.6))
                                .frame(width: 20, height: 20)
                        }
                    }

                    Text("Win up to \u{20AC}100 every month")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .rotationEffect(.degrees(showEligibility ? 180 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showEligibility)
            }
            .padding(16)

            // Expandable eligibility info
            if showEligibility {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(gold.opacity(0.5))
                        .padding(.top, 1)

                    Text("To be eligible for the Lottery, share the Milo Instagram post on your story and scan/upload at least 1 receipt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showEligibility)
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

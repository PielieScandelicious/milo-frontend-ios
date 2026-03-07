//
//  ReferralBonusClaimCard.swift
//  Scandalicious
//
//  Premium claim card shown at the top of the Home tab
//  when a referral reward is ready to be claimed.
//

import SwiftUI

struct ReferralBonusClaimCard: View {
    let onClaim: () -> Void

    private let accentBlue = Color(red: 0.35, green: 0.65, blue: 1.0)
    @State private var pulseScale: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        Button(action: onClaim) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentBlue.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentBlue)
                }

                // Text
                Text("Referral Bonus!")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Claim button
                Text("Claim")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [accentBlue, Color(red: 0.25, green: 0.45, blue: 0.95)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: accentBlue.opacity(0.4), radius: 8, y: 4)
                    )
                    .scaleEffect(pulseScale)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [accentBlue.opacity(0.3), accentBlue.opacity(0.1), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
            }
        }
    }
}

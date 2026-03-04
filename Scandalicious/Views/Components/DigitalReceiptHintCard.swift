//
//  DigitalReceiptHintCard.swift
//  Scandalicious
//
//  Hint card encouraging users to share digital receipts
//  for cashback rewards.
//

import SwiftUI

struct DigitalReceiptHintCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.85, green: 0.2, blue: 0.6).opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.85, green: 0.2, blue: 0.6))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Got a digital receipt?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Earn 0.5%\u{2013}1% cashback \u{2014} the more you spend, the higher your reward")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)

                Text("Cashback increases progressively in \u{20AC}50 segments, up to 1%")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
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

//
//  KickstartProgressView.swift
//  Scandalicious
//
//  Shown on the Home/Rewards tab during the Kickstart onboarding phase (first 3 tickets).
//  Replaces the streak card until kickstart is completed.
//

import SwiftUI

struct KickstartProgressView: View {
    let progress: KickstartProgress

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let goldGradient = [Color(red: 1.0, green: 0.88, blue: 0.35),
                                Color(red: 0.80, green: 0.60, blue: 0.0)]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(gold.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: goldGradient, startPoint: .top, endPoint: .bottom)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kickstart")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Upload je eerste 3 kassatickets")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                // Badge
                Text("NIEUW")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LinearGradient(colors: goldGradient, startPoint: .leading, endPoint: .trailing)))
            }

            // Three gift boxes
            HStack(spacing: 0) {
                ForEach(1...3, id: \.self) { i in
                    giftBox(number: i)
                    if i < 3 {
                        connector(completed: i < progress.ticketsCompleted)
                    }
                }
            }

            // Description for next ticket
            if !progress.isCompleted {
                let next = progress.ticketsCompleted + 1
                VStack(spacing: 4) {
                    Text(nextTicketTitle(for: next))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(nextTicketSubtitle(for: next))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
            } else {
                Label("Kickstart voltooid!", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(gold)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Gift Box

    @ViewBuilder
    private func giftBox(number: Int) -> some View {
        let isCompleted = number <= progress.ticketsCompleted
        let isNext = number == progress.ticketsCompleted + 1

        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isCompleted
                            ? LinearGradient(colors: goldGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [Color(white: isNext ? 0.15 : 0.09), Color(white: isNext ? 0.10 : 0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isCompleted ? Color.clear :
                                isNext ? gold.opacity(0.4) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: isCompleted ? gold.opacity(0.3) : .clear, radius: 8)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.black.opacity(0.8))
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isNext ? gold.opacity(0.8) : .white.opacity(0.2))
                }
            }

            Text("#\(number)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(
                    isCompleted ? gold :
                    isNext ? .white.opacity(0.7) :
                    .white.opacity(0.25)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func connector(completed: Bool) -> some View {
        Rectangle()
            .fill(completed ? gold.opacity(0.5) : Color(white: 0.12))
            .frame(height: 2)
            .frame(maxWidth: 20)
            .offset(y: -16) // vertically align with boxes
    }

    // MARK: - Copy

    private func nextTicketTitle(for ticket: Int) -> String {
        switch ticket {
        case 1: return "Upload je 1e kassaticket"
        case 2: return "Upload je 2e kassaticket voor +500 pts"
        case 3: return "Nog 1 kassaticket! +500 pts en je bent klaar"
        default: return "Kickstart voltooid!"
        }
    }

    private func nextTicketSubtitle(for ticket: Int) -> String {
        switch ticket {
        case 1: return "+500 pts + 1 Premium Spin 🎁"
        case 2: return "Nog 2 te gaan"
        case 3: return "Laatste stap — daarna start je streak!"
        default: return ""
        }
    }
}

//
//  StreakCardView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct StreakCardView: View {
    let streak: StreakData
    private let orange = Color(red: 1.0, green: 0.5, blue: 0.0)
    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let cashGreen = Color(red: 0.2, green: 0.85, blue: 0.4)

    var body: some View {
        VStack(spacing: 16) {
            // Top: flame + streak count + status
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(orange.opacity(0.1))
                        .frame(width: 46, height: 46)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [gold, orange, Color(red: 0.9, green: 0.2, blue: 0.1)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: orange.opacity(0.5), radius: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("\(streak.weekCount)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("week streak")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .offset(y: 2)
                    }

                    if streak.isAtRisk {
                        Text("Scan a receipt to keep your streak!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.9))
                    } else {
                        Text("Scan weekly to earn rewards")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }

                Spacer()

                if streak.isAtRisk {
                    Text("AT RISK")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.red.opacity(0.8)))
                } else if streak.hasShield {
                    Image(systemName: "shield.checkmark.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.cyan)
                }
            }

            // Progress bar showing current 4-week cycle
            streakProgressBar

            // Next cash reward preview
            nextCashRewardRow
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Progress Bar

    private var streakProgressBar: some View {
        let cycle = streak.currentCycle
        let completedCount = cycle.filter { $0.completed }.count

        return GeometryReader { geo in
            let width = geo.size.width
            let padding: CGFloat = 20
            let usable = width - padding * 2
            let spacing = usable / 3.0  // 3 gaps between 4 dots

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.12))
                    .frame(height: 3)
                    .padding(.horizontal, padding)

                // Filled track
                if completedCount > 0 {
                    let fillWidth = spacing * CGFloat(completedCount - 1) + (completedCount == 4 ? 0 : spacing * 0.5)
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [gold.opacity(0.8), orange],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: min(fillWidth, usable), height: 3)
                            .shadow(color: orange.opacity(0.4), radius: 4)
                        Spacer()
                    }
                    .padding(.leading, padding)
                }

                // Dots + labels
                ForEach(0..<4, id: \.self) { i in
                    let entry = cycle[i]
                    let xPos = padding + spacing * CGFloat(i)
                    let isNext = !entry.completed && (i == 0 || cycle[i - 1].completed)

                    VStack(spacing: 0) {
                        // Dot
                        ZStack {
                            if entry.isCash {
                                // Cash dot — larger
                                Circle()
                                    .fill(entry.completed ? cashGreen : Color(white: 0.06))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                entry.completed ? cashGreen.opacity(0.5) :
                                                isNext ? cashGreen.opacity(0.4) :
                                                Color(white: 0.2), lineWidth: 1.5
                                            )
                                    )
                                    .shadow(color: entry.completed ? cashGreen.opacity(0.4) : isNext ? cashGreen.opacity(0.2) : .clear, radius: 5)

                                if entry.completed {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(.white)
                                } else {
                                    Image(systemName: "banknote.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isNext ? cashGreen : cashGreen.opacity(0.4))
                                }
                            } else {
                                // Spin dot
                                Circle()
                                    .fill(entry.completed ? orange : Color(white: 0.06))
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                entry.completed ? gold.opacity(0.5) :
                                                isNext ? gold.opacity(0.3) :
                                                Color(white: 0.18), lineWidth: 1
                                            )
                                    )

                                if entry.completed {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 5, weight: .black))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .offset(y: -1)

                        // Week label
                        Text("W\(entry.week)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                entry.completed ? .white.opacity(0.6) :
                                isNext ? .white.opacity(0.8) :
                                .white.opacity(0.25)
                            )
                            .padding(.top, 6)

                        // Reward label
                        Text(entry.label)
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(
                                entry.isCash
                                    ? cashGreen.opacity(entry.completed ? 0.5 : isNext ? 1 : 0.4)
                                    : gold.opacity(entry.completed ? 0.5 : isNext ? 0.8 : 0.3)
                            )
                            .padding(.top, 1)
                    }
                    .position(x: xPos, y: 20)
                }
            }
        }
        .frame(height: 52)
    }

    // MARK: - Next Cash Reward Row

    private var nextCashRewardRow: some View {
        let cashReward = StreakData.weeklyReward(for: streak.nextCashWeek)

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(cashGreen.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "banknote.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(cashGreen)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Cash reward at week \(streak.nextCashWeek)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text(cashReward.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(cashGreen)
            }

            Spacer()

            Text("\(streak.weeksUntilCash)w left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(white: 0.1)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cashGreen.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

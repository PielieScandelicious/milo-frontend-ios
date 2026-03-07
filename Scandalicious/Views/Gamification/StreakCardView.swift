//
//  StreakCardView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct StreakCardView: View {
    let streak: StreakData
    var onClaim: (() -> Void)? = nil
    @ObservedObject private var gm = GamificationManager.shared

    @State private var claimPressed = false
    @State private var claimScale: CGFloat = 1.0
    @State private var showInfo = false

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
                    } else if streak.hasClaimableReward {
                        Text("Reward ready to claim!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(gold)
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

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showInfo.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(showInfo ? 0.7 : 0.3))
                }
                .buttonStyle(.plain)

                #if !PRODUCTION
                if gm.streakTestMode {
                    streakTestControls
                }
                #endif
            }
            #if !PRODUCTION
            .onLongPressGesture {
                gm.streakTestMode.toggle()
            }
            #endif

            // Info panel
            if showInfo {
                streakInfoPanel
            }

            // Progress bar showing current 4-week cycle
            streakProgressBar

            // Claim button
            if let reward = streak.claimableReward {
                claimButton(for: reward)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Claim Button

    @ViewBuilder
    private func claimButton(for reward: StreakClaimableRewardResponse) -> some View {
        let isCash = reward.rewardType == "cash"

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                claimScale = 0.92
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    claimScale = 1.0
                }
                onClaim?()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isCash ? "banknote.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text(isCash
                     ? "Claim \(String(format: "€%.2f", reward.cashAmount))"
                     : "Claim \(reward.spinsAmount) spin\(reward.spinsAmount > 1 ? "s" : "")")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        isCash
                            ? LinearGradient(
                                colors: [cashGreen, Color(red: 0.1, green: 0.7, blue: 0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [gold, orange],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(
                        color: (isCash ? cashGreen : orange).opacity(0.4),
                        radius: 12, y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(claimScale)
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

    // MARK: - Info Panel

    private var streakInfoPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // How it works
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gold)
                Text("How it works")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text("Scan at least one receipt over \u{20AC}50 each week to keep your streak going. Rewards grow the longer you keep it up!")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            // Reward tiers
            VStack(alignment: .leading, spacing: 6) {
                streakInfoRow(weeks: "Weeks 1-3", reward: "+1 spin / week", icon: "arrow.trianglehead.2.clockwise.rotate.90", color: gold)
                streakInfoRow(weeks: "Week 4", reward: "\u{20AC}1.00 cash", icon: "banknote.fill", color: cashGreen)
                streakInfoRow(weeks: "Weeks 5-7", reward: "+2 spins / week", icon: "arrow.trianglehead.2.clockwise.rotate.90", color: gold)
                streakInfoRow(weeks: "Week 8", reward: "\u{20AC}1.00 cash", icon: "banknote.fill", color: cashGreen)
                streakInfoRow(weeks: "Weeks 9-11", reward: "+3 spins / week", icon: "arrow.trianglehead.2.clockwise.rotate.90", color: gold)
                streakInfoRow(weeks: "Week 12+", reward: "\u{20AC}1.00 every 4th week", icon: "banknote.fill", color: cashGreen)
            }

            // Grace period note
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                Text("You have until Monday to scan and keep your streak.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }

    private func streakInfoRow(weeks: String, reward: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(weeks)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 72, alignment: .leading)

            Text(reward)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.85))
        }
    }

    // MARK: - Test Controls

    #if !PRODUCTION
    @ViewBuilder
    private var streakTestControls: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Button("+1") {
                    Task { await gm.testAdvanceStreak() }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.green)

                Button("W4") {
                    Task { await gm.testSetStreakWeek(4) }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.cyan)

                Button("W8") {
                    Task { await gm.testSetStreakWeek(8) }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.cyan)

                Button("W12") {
                    Task { await gm.testSetStreakWeek(12) }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.cyan)

                Button("Reset") {
                    Task { await gm.testResetStreak() }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
            }
        }
    }
    #endif

}

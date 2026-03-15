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

                        // Level 1 / Level 2 badge
                        Text(streak.levelDisplayName)
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.5)
                            .foregroundStyle(streak.isLevel2 ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(streak.isLevel2
                                    ? LinearGradient(colors: [gold, orange], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color(white: 0.2), Color(white: 0.15)], startPoint: .leading, endPoint: .trailing))
                            )
                            .offset(y: 2)
                    }

                    if streak.isAtRisk {
                        Text("Scan een kassaticket om je streak te houden!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.9))
                    } else if streak.hasClaimableReward {
                        Text("Beloning klaar om te claimen!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(gold)
                    } else if streak.isLevel2 {
                        Text("Level 2 — blijf scannen voor bonussen!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(gold.opacity(0.7))
                    } else {
                        Text("Scan wekelijks voor beloningen")
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
        let hasPoints = reward.pointsAmount > 0
        let hasSpin = reward.spinsAmount > 0
        let isPremium = reward.spinWheelType == .premium
        let accentColor: Color = isPremium ? gold : cashGreen

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { claimScale = 0.92 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { claimScale = 1.0 }
                onClaim?()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasSpin
                      ? (isPremium ? "crown.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                      : "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                // Build label: e.g. "Claim 150 pts" or "Claim 1 Premium Spin" or "Claim Spin + 100 pts"
                Group {
                    if hasSpin && hasPoints {
                        Text("Claim \(isPremium ? "Premium" : "Standaard") Spin + \(reward.pointsAmount) pts")
                    } else if hasSpin {
                        Text("Claim \(reward.spinsAmount) \(isPremium ? "Premium" : "Standaard") Spin")
                    } else {
                        Text("Claim \(reward.pointsAmount) pts")
                    }
                }
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        isPremium
                            ? LinearGradient(colors: [gold, orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [cashGreen, Color(red: 0.1, green: 0.7, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: accentColor.opacity(0.4), radius: 12, y: 4)
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

            Text("Scan elke week een kassaticket om je streak te houden. Level 2 geeft hogere beloningen!")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            // Level 1 schedule
            VStack(alignment: .leading, spacing: 4) {
                Text("Level 1 (maand 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 2)
                streakInfoRow(weeks: "Week 1", reward: "Geen beloning", icon: "xmark.circle", color: .white.opacity(0.3))
                streakInfoRow(weeks: "Week 2", reward: "+1 Standaard Spin", icon: "arrow.trianglehead.2.clockwise.rotate.90", color: gold)
                streakInfoRow(weeks: "Week 3", reward: "+150 pts", icon: "star.fill", color: cashGreen)
                streakInfoRow(weeks: "Week 4", reward: "+1 Premium Spin + 50 pts", icon: "crown.fill", color: gold)
            }

            // Level 2 schedule
            VStack(alignment: .leading, spacing: 4) {
                Text("Level 2 (doorlopend)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(gold.opacity(0.7))
                    .padding(.bottom, 2)
                streakInfoRow(weeks: "Week 1", reward: "+150 pts", icon: "star.fill", color: cashGreen)
                streakInfoRow(weeks: "Week 2", reward: "+1 Standaard Spin + 100 pts", icon: "arrow.trianglehead.2.clockwise.rotate.90", color: gold)
                streakInfoRow(weeks: "Week 3", reward: "+1 Standaard Spin + 150 pts", icon: "arrow.trianglehead.2.clockwise.rotate.90", color: gold)
                streakInfoRow(weeks: "Week 4", reward: "+1 Premium Spin + 200 pts", icon: "crown.fill", color: gold)
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                Text("Je hebt tot maandag om te scannen en je streak te bewaren.")
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

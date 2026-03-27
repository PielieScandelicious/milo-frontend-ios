//
//  MonthlyLotteryCard.swift
//  Scandalicious
//
//  Premium monthly lottery card with eligibility checklist,
//  inline IG handle input, and proof screenshot upload.
//

import SwiftUI

struct MonthlyLotteryCard: View {
    var lotteryStatus: LotteryStatus?
    var onStatusChanged: (() -> Void)?

    @State private var isExpanded = false
    @State private var instagramHandle = ""
    @State private var isSavingHandle = false
    @State private var handleSaved = false

    @State private var isDeclaring = false
    @State private var showConditionsAlert = false
    @State private var missingConditions: [String] = []

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let emerald = Color(red: 0.20, green: 0.78, blue: 0.55)

    private var completedSteps: Int {
        guard let s = lotteryStatus else { return 0 }
        var count = 0
        if s.hasInstagram { count += 1 }
        if s.hasReceipt { count += 1 }
        if s.hasShare { count += 1 }
        return count
    }

    private var monthLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return df.string(from: Date())
    }

    private var progressColor: Color {
        completedSteps == 3 ? emerald : gold
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            if isExpanded {
                expandedContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .background(cardBackground)
        .overlay(cardBorder)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
        .alert("Complete these steps first", isPresented: $showConditionsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(missingConditions.joined(separator: "\n"))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            progressRing
            headerText
            Spacer()
            stepDots
            chevron
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 3)
                .frame(width: 46, height: 46)

            Circle()
                .trim(from: 0, to: CGFloat(completedSteps) / 3.0)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(-90))

            Image(systemName: completedSteps == 3 ? "checkmark" : "gift.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(progressColor)
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(monthLabel) Lottery")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)

            if completedSteps == 3 {
                Text("You're in the draw!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(emerald)
            } else {
                let prize = lotteryStatus?.prizeAmount ?? 100
                Text("Win \u{20AC}\(prize) \u{2022} \(completedSteps)/3 completed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
    }

    private var stepDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                let color: Color = i < completedSteps ? progressColor : Color.white.opacity(0.1)
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.25))
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: 0) {
            dividerLine
            expandedBody
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [Color.white.opacity(0), Color.white.opacity(0.08), Color.white.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(height: 0.5)
            .padding(.horizontal, 18)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            prizeBanner
            step1Card
            step2Card
            step3Card
            winnerSection
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var prizeBanner: some View {
        HStack(spacing: 10) {
            let prize = lotteryStatus?.prizeAmount ?? 100
            Text("\u{20AC}\(prize)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(progressColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Monthly prize")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text("Complete all 3 steps to enter")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Step Cards

    private var step1Card: some View {
        let met = lotteryStatus?.hasInstagram ?? false
        let sub = met ? "Connected" : "Enter your handle below"
        return StepCardView(number: 1, met: met, title: "Link your Instagram", subtitle: sub, gold: gold, emerald: emerald) {
            if !met {
                instagramInput
            }
        }
    }

    private var step2Card: some View {
        let met = lotteryStatus?.hasReceipt ?? false
        let sub = met ? "Done" : "Scan any grocery receipt"
        return StepCardView(number: 2, met: met, title: "Upload a receipt this month", subtitle: sub, gold: gold, emerald: emerald) {
            EmptyView()
        }
    }

    private var postURL: String? {
        lotteryStatus?.postUrl
    }

    private var step3Card: some View {
        let met = lotteryStatus?.hasShare ?? false
        return StepCardView(number: 3, met: met, title: "Share our post on your story", subtitle: shareSubtitle, gold: gold, emerald: emerald) {
            if !met {
                VStack(alignment: .leading, spacing: 8) {
                    if postURL != nil {
                        postLinkRow
                    }
                    declareShareButton
                }
            }
        }
    }

    private var postLinkRow: some View {
        Button {
            if let urlString = postURL, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.51, green: 0.23, blue: 0.71),
                                    Color(red: 0.83, green: 0.18, blue: 0.42),
                                    Color(red: 1.0, green: 0.60, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                Text("Tap to view & share on story")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(gold.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        }
        .padding(.leading, 38)
    }

    @ViewBuilder
    private var winnerSection: some View {
        if let winner = lotteryStatus?.lastWinner {
            lastWinnerBanner(winner: winner)
        }
    }

    // MARK: - Instagram Input

    private var instagramInput: some View {
        HStack(spacing: 8) {
            handleField
            saveButton
        }
        .padding(.leading, 38)
    }

    private var handleField: some View {
        HStack(spacing: 4) {
            Text("@")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.3))

            TextField("your_handle", text: $instagramHandle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textContentType(.username)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var saveButton: some View {
        let bgColor: Color = instagramHandle.isEmpty ? gold.opacity(0.3) : gold
        return Button {
            saveInstagramHandle()
        } label: {
            Group {
                if isSavingHandle {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.8)
                } else if handleSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Text("Save")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(Color.black)
            .frame(width: 52, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(bgColor)
            )
        }
        .disabled(instagramHandle.isEmpty || isSavingHandle)
    }

    // MARK: - Share Declaration

    private var shareSubtitle: String {
        if lotteryStatus?.hasShare == true { return "Verified" }
        switch lotteryStatus?.proofStatus {
        case "pending_review": return "Awaiting verification"
        case "rejected": return "Not verified - try again"
        default: return "Share the post & confirm below"
        }
    }

    private var declareShareButton: some View {
        let isPending = lotteryStatus?.proofStatus == "pending_review"
        let fillColor: Color = isPending ? Color.orange.opacity(0.08) : gold.opacity(0.1)
        let strokeColor: Color = isPending ? Color.orange.opacity(0.2) : gold.opacity(0.2)

        return Button {
            declareShare()
        } label: {
            declareShareLabel
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(fillColor))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(strokeColor, lineWidth: 0.5))
        }
        .disabled(isDeclaring || isPending)
        .padding(.leading, 38)
    }

    @ViewBuilder
    private var declareShareLabel: some View {
        if isDeclaring {
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("Confirming...")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        } else if lotteryStatus?.proofStatus == "pending_review" {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill").font(.system(size: 12)).foregroundStyle(Color.orange)
                Text("Awaiting review")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(gold)
                Text("I shared it")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(gold)
            }
        }
    }

    // MARK: - Last Winner

    private func lastWinnerBanner(winner: LotteryWinner) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 12))
                .foregroundStyle(gold.opacity(0.6))

            Text("Last winner:")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.3))

            Text(winner.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))

            Text("@\(winner.instagramHandle)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(gold.opacity(0.5))

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(gold.opacity(0.03))
        )
    }

    // MARK: - Card Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(white: 0.08))
            .overlay(
                LinearGradient(
                    colors: [gold.opacity(0.03), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [gold.opacity(0.12), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }

    // MARK: - Actions

    private func saveInstagramHandle() {
        let handle = instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !handle.isEmpty else { return }

        isSavingHandle = true
        Task {
            do {
                _ = try await ProfileAPIService().updateProfile(
                    nickname: nil, gender: nil, age: nil,
                    language: nil, instagramHandle: handle
                )
                await MainActor.run {
                    isSavingHandle = false
                    handleSaved = true
                    onStatusChanged?()
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { handleSaved = false }
            } catch {
                await MainActor.run { isSavingHandle = false }
            }
        }
    }

    private func declareShare() {
        var missing: [String] = []
        if lotteryStatus?.hasInstagram != true {
            missing.append("Step 1: Link your Instagram account")
        }
        if lotteryStatus?.hasReceipt != true {
            missing.append("Step 2: Scan a receipt this month")
        }
        if !missing.isEmpty {
            missingConditions = missing
            showConditionsAlert = true
            return
        }

        isDeclaring = true
        Task {
            do {
                try await LotteryAPIService().declareShare()
                await MainActor.run {
                    isDeclaring = false
                    onStatusChanged?()
                }
            } catch {
                await MainActor.run { isDeclaring = false }
            }
        }
    }
}

// MARK: - Step Card (separate struct to reduce type-checker load)

private struct StepCardView<Content: View>: View {
    let number: Int
    let met: Bool
    let title: String
    let subtitle: String
    let gold: Color
    let emerald: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        let bgColor: Color = met ? emerald.opacity(0.04) : Color.white.opacity(0.03)
        let borderColor: Color = met ? emerald.opacity(0.12) : Color.white.opacity(0.04)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                stepIndicator
                stepText
                Spacer()
            }
            content()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(bgColor))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 0.5))
    }

    private var stepIndicator: some View {
        let circleFill: Color = met ? emerald.opacity(0.15) : Color.white.opacity(0.05)
        return ZStack {
            Circle()
                .fill(circleFill)
                .frame(width: 28, height: 28)

            if met {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(emerald)
            } else {
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
    }

    private var stepText: some View {
        let titleColor: Color = met ? Color.white.opacity(0.5) : Color.white
        let subtitleColor: Color = met ? emerald.opacity(0.7) : Color.white.opacity(0.35)
        return VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(titleColor)
                .strikethrough(met, color: Color.white.opacity(0.3))

            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(subtitleColor)
        }
    }
}

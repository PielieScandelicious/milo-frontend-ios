//
//  WithdrawCardView.swift
//  Scandalicious
//

import SwiftUI

struct WithdrawCardView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var selectedAmount: Double? = nil
    @State private var showWithdrawFlow = false
    @State private var showHistory = false

    private let brandPurple = Color(red: 0.45, green: 0.15, blue: 0.85)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
                Text("Withdraw Cash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()

                #if !PRODUCTION
                if gm.withdrawalTestMode {
                    testControls
                }
                #endif
            }
            #if !PRODUCTION
            .onLongPressGesture {
                gm.withdrawalTestMode.toggle()
            }
            #endif

            if let active = gm.activeWithdrawal,
               ["pending_review", "auto_approved", "approved"].contains(active.status) {
                // Show status tracker
                WithdrawalStatusTracker(withdrawal: active)
            } else if let active = gm.activeWithdrawal, active.status == "rejected" {
                // Show rejection notice
                rejectionNotice(active)
            } else if let info = gm.withdrawalInfo {
                if info.canWithdraw {
                    withdrawContent(info: info)
                } else {
                    ineligibleContent(reason: info.cannotWithdrawReason ?? "Not eligible")
                }
            } else {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white.opacity(0.5))
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // History link
            if !gm.withdrawalHistory.isEmpty || gm.hasPendingWithdrawal {
                Button {
                    showHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Text("View history")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(16)
        .glassCard()
        .sheet(isPresented: $showWithdrawFlow) {
            WithdrawFlowView(
                preselectedAmount: selectedAmount ?? 5,
                lastIban: gm.withdrawalInfo?.lastIban
            )
        }
        .sheet(isPresented: $showHistory) {
            WithdrawalHistoryView()
        }
        .onAppear {
            gm.fetchWithdrawalInfo()
            gm.fetchWithdrawalHistory()
        }
    }

    // MARK: - Withdraw Content

    @ViewBuilder
    private func withdrawContent(info: WithdrawalInfoResponse) -> some View {
        // Balance
        HStack {
            Text("Balance:")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(String(format: "€%.2f", info.currentBalance))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }

        // Amount chips
        HStack(spacing: 8) {
            ForEach([5.0, 10.0, 15.0, 20.0], id: \.self) { amount in
                let available = info.availableAmounts.contains(amount)
                Button {
                    if available {
                        selectedAmount = amount
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Text("€\(Int(amount))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            selectedAmount == amount ? .white :
                            available ? Color(red: 1.0, green: 0.84, blue: 0.0) :
                            .white.opacity(0.3)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    selectedAmount == amount ?
                                    brandPurple.opacity(0.6) :
                                    Color(white: available ? 0.12 : 0.06)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedAmount == amount ?
                                    brandPurple : Color.white.opacity(available ? 0.1 : 0.05),
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!available)
            }
        }

        // Withdraw button
        Button {
            if selectedAmount != nil {
                showWithdrawFlow = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } label: {
            Text("WITHDRAW")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            selectedAmount != nil ?
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.8, blue: 0.4),
                                         Color(red: 0.1, green: 0.5, blue: 0.25)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color(white: 0.2), Color(white: 0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: selectedAmount != nil ?
                            Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.4) : .clear,
                            radius: 12, y: 6)
                )
        }
        .buttonStyle(.plain)
        .disabled(selectedAmount == nil)
        .opacity(selectedAmount == nil ? 0.5 : 1.0)
    }

    // MARK: - Ineligible Content

    @ViewBuilder
    private func ineligibleContent(reason: String) -> some View {
        if let info = gm.withdrawalInfo,
           reason.lowercased().contains("receipt") || reason.lowercased().contains("scan") {
            receiptProgressContent(
                count: info.confirmedCashbackCount ?? 0,
                required: 5,
                reason: reason
            )
        } else {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
                Text(reason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func receiptProgressContent(count: Int, required: Int, reason: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.8))
                Text(reason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.84, blue: 0.0),
                                         Color(red: 0.9, green: 0.6, blue: 0.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * min(CGFloat(count) / CGFloat(required), 1.0),
                            height: 6
                        )
                        .animation(.spring(response: 0.5), value: count)
                }
            }
            .frame(height: 6)

            HStack {
                ForEach(0..<required, id: \.self) { i in
                    Circle()
                        .fill(i < count ? Color(red: 1.0, green: 0.84, blue: 0.0) : Color.white.opacity(0.1))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle().stroke(Color.white.opacity(i < count ? 0 : 0.2), lineWidth: 1)
                        )
                }
                Spacer()
                Text("\(count)/\(required) receipts")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Rejection Notice

    @ViewBuilder
    private func rejectionNotice(_ withdrawal: WithdrawalItemResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Withdrawal declined")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            if let notes = withdrawal.adminNotes {
                Text(notes)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text("€\(String(format: "%.2f", withdrawal.amount)) has been refunded to your balance")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Test Controls

    #if !PRODUCTION
    @ViewBuilder
    private var testControls: some View {
        HStack(spacing: 6) {
            if let active = gm.activeWithdrawal,
               ["pending_review", "auto_approved", "approved"].contains(active.status) {
                Button("Process") {
                    Task {
                        try? await gm.testAutoProcessWithdrawal(active.id)
                    }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green)
            }

            Button("Reset") {
                Task {
                    try? await gm.testResetWithdrawals()
                }
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.orange)
        }
    }
    #endif
}

// MARK: - Status Tracker

private struct WithdrawalStatusTracker: View {
    let withdrawal: WithdrawalItemResponse
    @State private var pulseOpacity: Double = 1.0

    private var currentStep: Int {
        switch withdrawal.status {
        case "pending_review": return 1
        case "auto_approved", "approved": return 2
        case "paid_out": return 3
        default: return 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Amount and IBAN
            HStack {
                Text(String(format: "€%.2f", withdrawal.amount))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("to ****\(withdrawal.ibanLast4)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Steps
            VStack(alignment: .leading, spacing: 6) {
                statusStep(index: 0, label: "Submitted", isCompleted: currentStep >= 0, isActive: currentStep == 0)
                statusStep(index: 1, label: "Under Review", isCompleted: currentStep >= 1, isActive: currentStep == 1)
                statusStep(index: 2, label: "Approved", isCompleted: currentStep >= 2, isActive: currentStep == 2)
                statusStep(index: 3, label: "Paid Out", isCompleted: currentStep >= 3, isActive: currentStep == 3)
            }

            // Estimated time
            if currentStep < 3 {
                Text("Estimated: within 48 hours")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Text("Transfer complete")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
    }

    @ViewBuilder
    private func statusStep(index: Int, label: String, isCompleted: Bool, isActive: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if isCompleted {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.8, blue: 0.4))
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                } else if isActive {
                    Circle()
                        .fill(Color(red: 0.45, green: 0.15, blue: 0.85))
                        .frame(width: 18, height: 18)
                        .opacity(pulseOpacity)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }

            Text(label)
                .font(.system(size: 13, weight: isCompleted || isActive ? .semibold : .regular))
                .foregroundStyle(isCompleted || isActive ? .white : .white.opacity(0.3))

            Spacer()
        }
    }
}

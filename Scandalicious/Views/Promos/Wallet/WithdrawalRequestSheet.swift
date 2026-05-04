//
//  WithdrawalRequestSheet.swift
//  Scandalicious
//
//  Two-step withdrawal sheet: pick amount + IBAN, then confirm. Submits
//  through WithdrawalAPIService and tells the wallet view model to refresh
//  on success so the new pending row appears immediately.
//

import SwiftUI

struct WithdrawalRequestSheet: View {
    @Environment(\.dismiss) private var dismiss

    let info: WithdrawalInfoResponse
    let onSuccess: () -> Void

    @State private var selectedAmount: Double
    @State private var iban: String = ""
    @State private var step: Step = .pick
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)

    enum Step { case pick, confirm }

    init(info: WithdrawalInfoResponse, onSuccess: @escaping () -> Void) {
        self.info = info
        self.onSuccess = onSuccess
        _selectedAmount = State(initialValue: info.availableAmounts.first ?? 5)
        _iban = State(initialValue: info.lastIban ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()

                if showSuccess {
                    successView
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                switch step {
                                case .pick:    pickStep
                                case .confirm: confirmStep
                                }
                            }
                            .padding(20)
                        }

                        bottomButton
                            .padding(20)
                    }
                }
            }
            .navigationTitle("Withdraw")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .confirm && !showSuccess {
                        Button {
                            withAnimation { step = .pick }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.white)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pick step

    private var pickStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Available")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(MoneyFormatter.eur(cents: info.balanceCents))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(cashbackGreen)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Amount")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 8) {
                    ForEach(info.availableAmounts, id: \.self) { amount in
                        amountChip(amount)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("IBAN")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                TextField("BE… ", text: $iban)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .foregroundStyle(.white)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func amountChip(_ amount: Double) -> some View {
        let isSelected = abs(amount - selectedAmount) < 0.001
        return Button {
            selectedAmount = amount
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(MoneyFormatter.eur(amount))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isSelected ? cashbackGreen : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirm step

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            confirmRow(label: "Amount", value: MoneyFormatter.eur(selectedAmount))
            confirmRow(label: "To IBAN", value: maskedIban)
            confirmRow(
                label: "Balance after",
                value: MoneyFormatter.eur(cents: info.balanceCents - Int(selectedAmount * 100))
            )

            Text("Funds usually arrive in 1–3 business days. We'll review the request before sending.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)
        }
    }

    private func confirmRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var maskedIban: String {
        let cleaned = iban.replacingOccurrences(of: " ", with: "").uppercased()
        guard cleaned.count >= 4 else { return cleaned }
        return "•••• " + String(cleaned.suffix(4))
    }

    // MARK: - Bottom button

    private var bottomButton: some View {
        Button {
            handlePrimary()
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(step == .pick ? "Continue" : "Confirm withdrawal")
                        .font(.system(size: 16, weight: .heavy))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(canSubmit ? cashbackGreen : Color.white.opacity(0.1))
            )
        }
        .disabled(!canSubmit || isSubmitting)
    }

    private var canSubmit: Bool {
        let trimmed = iban.replacingOccurrences(of: " ", with: "")
        return trimmed.count >= 15 && selectedAmount > 0
    }

    // MARK: - Submit

    private func handlePrimary() {
        switch step {
        case .pick:
            withAnimation { step = .confirm }
        case .confirm:
            submit()
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            defer { Task { @MainActor in isSubmitting = false } }
            do {
                _ = try await WithdrawalAPIService.shared.submitWithdrawal(
                    amount: selectedAmount,
                    iban: iban
                )
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        showSuccess = true
                    }
                    onSuccess()
                }
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { dismiss() }
            } catch let error as WalletAPIError {
                await MainActor.run { errorMessage = error.errorDescription }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(cashbackGreen)
            Text("Request sent")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
            Text("We'll notify you once it's reviewed.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

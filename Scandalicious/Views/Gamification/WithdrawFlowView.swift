//
//  WithdrawFlowView.swift
//  Scandalicious
//

import SwiftUI

struct WithdrawFlowView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @Environment(\.dismiss) private var dismiss

    let preselectedAmount: Double
    let lastIban: String?

    @State private var iban: String = ""
    @State private var step: FlowStep = .iban
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil
    @State private var ibanError: String? = nil

    private let brandGreen = Color(red: 0.2, green: 0.8, blue: 0.4)

    enum FlowStep {
        case iban, confirm
    }

    init(preselectedAmount: Double, lastIban: String?) {
        self.preselectedAmount = preselectedAmount
        self.lastIban = lastIban
        _iban = State(initialValue: lastIban ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                if showSuccess {
                    successView
                } else {
                    VStack(spacing: 0) {
                        // Progress indicator
                        progressBar

                        ScrollView {
                            VStack(spacing: 24) {
                                switch step {
                                case .iban:
                                    ibanStep
                                case .confirm:
                                    confirmStep
                                }
                            }
                            .padding(20)
                        }

                        // Bottom button
                        bottomButton
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .confirm && !showSuccess {
                        Button {
                            withAnimation {
                                step = .iban
                            }
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
        .presentationDetents([.large])
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(i <= stepIndex ? brandGreen : Color.white.opacity(0.1))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var stepIndex: Int {
        switch step {
        case .iban: return 0
        case .confirm: return 1
        }
    }

    // MARK: - IBAN Step

    private var ibanStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enter your IBAN")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("We'll transfer €\(Int(preselectedAmount)) to this bank account")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            VStack(alignment: .leading, spacing: 8) {
                TextField("", text: $iban, prompt: Text("BE00 0000 0000 0000").foregroundStyle(.white.opacity(0.2)))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                ibanError != nil ? .red.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
                    .onChange(of: iban) { _ in
                        ibanError = nil
                    }

                if let error = ibanError {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Your IBAN is stored securely and only used for transfers")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Confirm Step

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Confirm withdrawal")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 16) {
                confirmRow(label: "Amount", value: "€\(Int(preselectedAmount))")
                confirmRow(label: "To IBAN", value: maskedIBAN)
                confirmRow(label: "Processing", value: "Within 48 hours")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.08))
            )

            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Your withdrawal will be reviewed within 48 hours. You'll see the status update in real-time.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    @ViewBuilder
    private func confirmRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var maskedIBAN: String {
        let cleaned = iban.replacingOccurrences(of: " ", with: "").uppercased()
        guard cleaned.count >= 4 else { return iban }
        let prefix = String(cleaned.prefix(2))
        let last4 = String(cleaned.suffix(4))
        return "\(prefix)****\(last4)"
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack {
            Button {
                handleNext()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(step == .confirm ? "CONFIRM WITHDRAWAL" : "CONTINUE")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: step == .confirm ?
                                    [Color(red: 0.2, green: 0.8, blue: 0.4),
                                     Color(red: 0.1, green: 0.5, blue: 0.25)] :
                                    [Color(red: 0.45, green: 0.15, blue: 0.85),
                                     Color(red: 0.3, green: 0.1, blue: 0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || !canProceed)
            .opacity(canProceed ? 1 : 0.5)
        }
        .padding(20)
        .background(Color(white: 0.05))
    }

    private var canProceed: Bool {
        switch step {
        case .iban: return !iban.trimmingCharacters(in: .whitespaces).isEmpty
        case .confirm: return true
        }
    }

    // MARK: - Actions

    private func handleNext() {
        switch step {
        case .iban:
            let cleaned = iban.replacingOccurrences(of: " ", with: "").uppercased()

            #if !PRODUCTION
            if gm.withdrawalTestMode {
                withAnimation { step = .confirm }
                return
            }
            #endif

            if !Self.isValidIBAN(cleaned) {
                ibanError = "Please enter a valid IBAN"
                return
            }
            withAnimation { step = .confirm }
        case .confirm:
            submitWithdrawal()
        }
    }

    private func submitWithdrawal() {
        isSubmitting = true
        let cleanedIBAN = iban.replacingOccurrences(of: " ", with: "").uppercased()

        Task {
            do {
                _ = try await gm.submitWithdrawal(amount: preselectedAmount, iban: cleanedIBAN)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showSuccess = true
                }
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isSubmitting = false
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(brandGreen.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(brandGreen)
            }

            Text("Withdrawal submitted!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("We'll review your withdrawal of €\(Int(preselectedAmount)) within 48 hours. You can track the status on the Rewards page.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("DONE")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [brandGreen, Color(red: 0.1, green: 0.5, blue: 0.25)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(20)
        }
    }

    // MARK: - IBAN Validation

    static func isValidIBAN(_ iban: String) -> Bool {
        let cleaned = iban.replacingOccurrences(of: " ", with: "").uppercased()
        guard cleaned.count >= 15, cleaned.count <= 34 else { return false }
        guard cleaned.prefix(2).allSatisfy({ $0.isLetter }) else { return false }
        guard cleaned.dropFirst(2).prefix(2).allSatisfy({ $0.isNumber }) else { return false }

        // Mod97 check
        let rearranged = String(cleaned.dropFirst(4)) + String(cleaned.prefix(4))
        var remainder = 0
        for char in rearranged {
            let value: Int
            if let digit = char.wholeNumberValue {
                value = digit
                remainder = (remainder * 10 + value) % 97
            } else if let ascii = char.asciiValue {
                let numericValue = Int(ascii) - 55 // A=10, B=11, etc.
                // Two-digit number
                remainder = (remainder * 100 + numericValue) % 97
            }
        }
        return remainder == 1
    }
}

//
//  CharityDonateFlowView.swift
//  Scandalicious
//

import SwiftUI

struct CharityDonateFlowView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @Environment(\.dismiss) private var dismiss

    // Flow state
    @State private var step: Step = .selectCharity
    @State private var selectedCharity: CharityItem? = nil
    @State private var selectedAmount: Double? = nil
    @State private var isLoading = false
    @State private var successResponse: CharityDonateResponse? = nil
    @State private var errorMessage: String? = nil

    private let brandPurple = Color(red: 0.45, green: 0.15, blue: 0.85)

    enum Step { case selectCharity, selectAmount, confirm, success }

    private var availableAmounts: [Double] {
        let balance = gm.charityUserBalance
        return [5.0, 10.0, 15.0, 20.0].filter { $0 <= balance }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step indicator
                    if step != .success {
                        stepIndicator
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                    }

                    switch step {
                    case .selectCharity: charitySelectionStep
                    case .selectAmount:  amountSelectionStep
                    case .confirm:       confirmStep
                    case .success:       successStep
                    }
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step == .selectCharity || step == .success {
                        Button("Close") { dismiss() }
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                step = step == .selectAmount ? .selectCharity : .selectAmount
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Back")
                            }
                            .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                let currentIndex = stepIndex
                Capsule()
                    .fill(i <= currentIndex ? brandPurple : Color.white.opacity(0.12))
                    .frame(height: 4)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
    }

    private var stepIndex: Int {
        switch step {
        case .selectCharity: return 0
        case .selectAmount:  return 1
        case .confirm, .success: return 2
        }
    }

    private var stepTitle: String {
        switch step {
        case .selectCharity: return "Choose Charity"
        case .selectAmount:  return "Select Amount"
        case .confirm:       return "Confirm Donation"
        case .success:       return "Donation Sent"
        }
    }

    // MARK: - Step 1: Select Charity

    private var charitySelectionStep: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(gm.charities) { charity in
                    charityCard(charity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func charityCard(_ charity: CharityItem) -> some View {
        let isSelected = selectedCharity?.id == charity.id
        let accentColor = charityColor(charity.color)

        Button {
            selectedCharity = charity
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35)) { step = .selectAmount }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(isSelected ? 0.25 : 0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: charity.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Text(charity.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(charity.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Community total
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(accentColor.opacity(0.7))
                    Text(String(format: "€%.0f raised", charity.communityTotal))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? accentColor.opacity(0.12) : Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.06),
                                    lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Select Amount

    private var amountSelectionStep: some View {
        VStack(spacing: 24) {
            // Selected charity recap
            if let charity = selectedCharity {
                let accentColor = charityColor(charity.color)
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: charity.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(charity.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Text(charity.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accentColor.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.2), lineWidth: 0.5))
                )
                .padding(.horizontal, 20)
            }

            // Balance
            HStack {
                Text("Your balance:")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                Text(String(format: "€%.2f", gm.charityUserBalance))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 20)

            if availableAmounts.isEmpty {
                // Insufficient balance
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Minimum donation is €5. Scan more receipts to earn rewards.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
            } else {
                // Amount chips
                HStack(spacing: 10) {
                    ForEach([5.0, 10.0, 15.0, 20.0], id: \.self) { amount in
                        let available = availableAmounts.contains(amount)
                        Button {
                            if available {
                                selectedAmount = amount
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        } label: {
                            Text("€\(Int(amount))")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    selectedAmount == amount ? .white :
                                    available ? Color(red: 1.0, green: 0.84, blue: 0.0) :
                                    .white.opacity(0.2)
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedAmount == amount ? brandPurple.opacity(0.6) :
                                              Color(white: available ? 0.12 : 0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedAmount == amount ? brandPurple :
                                                Color.white.opacity(available ? 0.1 : 0.04),
                                                lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!available)
                    }
                }
                .padding(.horizontal, 20)

                // Next button
                Button {
                    if selectedAmount != nil {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35)) { step = .confirm }
                    }
                } label: {
                    Text("NEXT")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedAmount != nil ?
                                      LinearGradient(colors: [brandPurple, Color(red: 0.6, green: 0.2, blue: 1.0)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing) :
                                      LinearGradient(colors: [Color(white: 0.15), Color(white: 0.12)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: selectedAmount != nil ? brandPurple.opacity(0.4) : .clear,
                                        radius: 10, y: 5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedAmount == nil)
                .opacity(selectedAmount == nil ? 0.5 : 1.0)
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    // MARK: - Step 3: Confirm

    private var confirmStep: some View {
        VStack(spacing: 24) {
            if let charity = selectedCharity, let amount = selectedAmount {
                let accentColor = charityColor(charity.color)

                // Summary card
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: charity.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }

                    VStack(spacing: 6) {
                        Text(charity.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text(charity.description)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }

                    // Amount display
                    Text(String(format: "€%.0f", amount))
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )

                    // Info note
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("€\(String(format: "%.0f", amount)) will be deducted from your Milo balance. Milo transfers collected donations monthly.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.1))
                )
                .padding(.horizontal, 20)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Confirm button
                Button {
                    Task { await confirmDonation() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("CONFIRM DONATION")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.8)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: accentColor.opacity(0.4), radius: 12, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1.0)
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    // MARK: - Step 4: Success

    private var successStep: some View {
        VStack(spacing: 30) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color(red: 0.45, green: 0.15, blue: 0.85).opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(red: 0.45, green: 0.15, blue: 0.85))
            }
            .transition(.scale.combined(with: .opacity))

            if let resp = successResponse, let charity = selectedCharity {
                VStack(spacing: 10) {
                    Text("Thank you!")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your €\(String(format: "%.0f", resp.amount)) donation to \(charity.name) has been registered.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if !resp.fraudCheckPassed {
                        Text("Your donation is under review and will be processed shortly.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }

            // New balance
            if let resp = successResponse {
                VStack(spacing: 4) {
                    Text("New balance")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(String(format: "€%.2f", resp.newBalance))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                )
            }

            Spacer()

            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Confirm Donation Action

    private func confirmDonation() async {
        guard let charity = selectedCharity, let amount = selectedAmount else { return }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await gm.submitCharityDonation(charityId: charity.id, amount: amount)
            successResponse = response
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5)) { step = .success }
        } catch let error as CashbackAPIError {
            switch error {
            case .serverError(let msg): errorMessage = msg
            default: errorMessage = "Something went wrong. Please try again."
            }
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func charityColor(_ name: String) -> Color {
        switch name {
        case "red":    return Color(red: 0.93, green: 0.27, blue: 0.27)
        case "orange": return Color(red: 0.98, green: 0.58, blue: 0.2)
        case "blue":   return Color(red: 0.24, green: 0.56, blue: 0.96)
        case "green":  return Color(red: 0.2, green: 0.78, blue: 0.45)
        case "purple": return Color(red: 0.55, green: 0.25, blue: 0.9)
        case "yellow": return Color(red: 1.0, green: 0.84, blue: 0.0)
        default:       return Color(red: 0.45, green: 0.15, blue: 0.85)
        }
    }
}

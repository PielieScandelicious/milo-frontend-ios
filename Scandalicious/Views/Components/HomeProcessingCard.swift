//
//  HomeProcessingCard.swift
//  Scandalicious
//
//  Processing card with two states: actively processing (with progress bar
//  and "play while you wait" message) and done (reward ready to claim).
//

import SwiftUI

struct HomeProcessingCard: View {
    @Bindable var viewModel: HomeViewModel

    @State private var pulseGlow = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.processingPhase == .processing {
                processingContent
            } else if viewModel.processingPhase == .done {
                doneContent
            }
        }
        .background(cardBackground)
        .overlay(
            viewModel.processingPhase == .done
                ? RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.4).opacity(pulseGlow ? 0.35 : 0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseGlow)
                : nil
        )
        .overlay(
            viewModel.processingPhase != .done
                ? cardBorder
                : nil
        )
        .onTapGesture {
            if viewModel.processingPhase == .done {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.claimReward()
            }
        }
        .onAppear {
            pulseGlow = true
        }
    }

    // MARK: - Processing Content

    private var processingContent: some View {
        VStack(spacing: 12) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                    .symbolEffect(.rotate, isActive: true)

                Text("Processing your receipt...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Progress bar
            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.7, blue: 1.0),
                                    Color(red: 0.45, green: 0.15, blue: 0.85)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: nil,
                            alignment: .leading
                        )
                        .scaleEffect(
                            x: max(0.01, viewModel.processingProgress),
                            y: 1,
                            anchor: .leading
                        )
                }
                .clipShape(Capsule())
                .padding(.horizontal, 16)

            // Play while you wait hint pointing to easter egg above
            HStack(spacing: 5) {
                Text("Tap Milo to play while you wait")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))

                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.bottom, 10)
        }
    }

    // MARK: - Done Content

    private var doneContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Your reward is ready!")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("Tap to claim your cashback")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Card Styling

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

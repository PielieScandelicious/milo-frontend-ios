//
//  PendingTransactionsNotification.swift
//  Scandalicious
//
//  Created by Claude on 02/02/2026.
//

import SwiftUI

// MARK: - Pending Transactions Banner

/// A sleek bottom notification banner that appears when new bank transactions need review
struct PendingTransactionsNotification: View {
    let transactionCount: Int
    let onReviewTapped: () -> Void
    let onDismiss: () -> Void

    @State private var isAppearing = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon with animated pulse
            ZStack {
                Circle()
                    .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.2))
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.15))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isAppearing ? 1.2 : 1.0)
                    .opacity(isAppearing ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAppearing
                    )

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("\(transactionCount) New Transaction\(transactionCount == 1 ? "" : "s")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("Tap to review and categorize")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Review Button
            Button {
                onReviewTapped()
            } label: {
                Text("Review")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                    .cornerRadius(8)
            }
            .buttonStyle(ScaleButtonStyle())

            // Dismiss Button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .padding(.horizontal, 16)
        .onAppear {
            // Start pulse animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAppearing = true
            }
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Notification Modifier

extension View {
    /// Shows a bottom notification banner when pending transactions are available
    func pendingTransactionsNotification(
        isPresented: Binding<Bool>,
        transactionCount: Int,
        onReviewTapped: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .bottom) {
            self

            if isPresented.wrappedValue && transactionCount > 0 {
                PendingTransactionsNotification(
                    transactionCount: transactionCount,
                    onReviewTapped: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented.wrappedValue = false
                        }
                        onReviewTapped()
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented.wrappedValue = false
                        }
                        onDismiss()
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
                .padding(.bottom, 100) // Above tab bar
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented.wrappedValue)
    }
}

// MARK: - Preview

#Preview("Notification Banner") {
    ZStack {
        Color(white: 0.08)
            .ignoresSafeArea()

        VStack {
            Spacer()

            PendingTransactionsNotification(
                transactionCount: 5,
                onReviewTapped: { },
                onDismiss: { }
            )
            .padding(.bottom, 100)
        }
    }
}

#Preview("Single Transaction") {
    ZStack {
        Color(white: 0.08)
            .ignoresSafeArea()

        VStack {
            Spacer()

            PendingTransactionsNotification(
                transactionCount: 1,
                onReviewTapped: { },
                onDismiss: { }
            )
            .padding(.bottom, 100)
        }
    }
}

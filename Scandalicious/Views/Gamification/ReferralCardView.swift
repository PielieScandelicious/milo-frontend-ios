//
//  ReferralCardView.swift
//  Scandalicious
//
//  Premium referral card for the Rewards tab.
//

import SwiftUI

struct ReferralCardView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var showShareSheet = false
    @State private var codeCopied = false
    @State private var showInfo = false

    private let accentColor = Color(red: 0.35, green: 0.65, blue: 1.0)
    private let accentGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.65, blue: 1.0), Color(red: 0.2, green: 0.45, blue: 0.9)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 16) {
            // Header row — tappable to toggle info
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("REFER A FRIEND")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.5))
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Text("You both earn \u{20AC}1")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()

                // Referral count badge
                if gm.referralCount > 0 {
                    VStack(spacing: 2) {
                        Text("\(gm.referralCount)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("referred")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showInfo.toggle()
                }
            }

            // Code display + share button
            HStack(spacing: 12) {
                // Code pill — tap to copy
                if let code = gm.referralCode {
                    Button {
                        UIPasteboard.general.string = code
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            codeCopied = true
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { codeCopied = false }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(codeCopied ? "COPIED!" : code)
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .tracking(3)

                            if !codeCopied {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(codeCopied ? 0.1 : 0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            codeCopied ? accentColor.opacity(0.6) : accentColor.opacity(0.2),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    ProgressView()
                        .tint(.white.opacity(0.4))
                        .frame(height: 40)
                }

                Spacer()

                // Share button
                Button {
                    showShareSheet = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text("SHARE")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(accentGradient)
                            .shadow(color: accentColor.opacity(0.4), radius: 10, y: 5)
                    )
                }
                .disabled(gm.referralCode == nil)
            }

            // Referral condition — revealed on tap
            if showInfo {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Reward unlocks when your friend scans a receipt over \u{20AC}50")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard(borderGradient: LinearGradient(
            colors: [accentColor.opacity(0.2), accentColor.opacity(0.05)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .sheet(isPresented: $showShareSheet) {
            if let code = gm.referralCode {
                ShareSheet(items: [referralShareText(code: code)])
            }
        }
        .onAppear {
            gm.fetchReferralInfo()
        }
    }

    private func referralShareText(code: String) -> String {
        "Hey! I've been using Scandalicious to earn cashback on my groceries. Use my referral code \(code) when you sign up and we both get \u{20AC}1 + 3 free spins after you scan your first receipt over \u{20AC}50! Download here: https://apps.apple.com/app/scandalicious/id6742044938"
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

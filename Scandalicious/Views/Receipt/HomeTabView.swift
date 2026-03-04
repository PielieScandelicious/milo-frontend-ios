//
//  HomeTabView.swift
//  Scandalicious
//
//  Redesigned home tab with mock data, processing flow,
//  mini game integration, and premium card-based UI.
//

import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject private var rateLimitManager = RateLimitManager.shared
    @ObservedObject private var processingManager = ReceiptProcessingManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var viewModel = HomeViewModel()
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showProfile = false
    @State private var showRateLimitAlert = false
    @State private var contentOpacity: Double = 0
    @State private var showMiloGame = false
    @State private var showWalletPassCreator = false
    @Environment(\.scenePhase) private var scenePhase

    private let headerBlueColor = Color(red: 0.04, green: 0.15, blue: 0.30)
    private let deepPurple = Color(red: 0.35, green: 0.10, blue: 0.60)

    var body: some View {
        NavigationStack {
            ZStack {
                // Main scrollable content
                mainContent

                // Floating scan button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingScanButton
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }

                // Cashback reveal overlay
                if viewModel.showCashbackReveal {
                    CashbackRevealOverlay(viewModel: viewModel)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileMenuButton
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CustomCameraView(capturedImage: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newImage in
            guard let image = newImage else { return }
            capturedImage = nil
            viewModel.uploadAndProcess(image: image)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkForShareExtensionUploads()
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .environmentObject(authManager)
                    .environmentObject(subscriptionManager)
            }
        }
        .sheet(isPresented: $showWalletPassCreator) {
            WalletPassCreatorView()
        }
        .alert("Upload Limit Reached", isPresented: $showRateLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rateLimitManager.receiptLimitMessage ?? "You've reached your monthly upload limit.")
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Milo dachshund easter egg (always visible when game not open)
                if !showMiloGame {
                    MiloDachshundEasterEgg {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            showMiloGame = true
                        }
                    }
                }

                // Inline Milo Game (when active) - on top of processing card
                if showMiloGame {
                    MiloDogGameView()
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Close game button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showMiloGame = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Close game")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }

                // Processing card below the game (when processing or done)
                if viewModel.processingPhase != .idle && viewModel.processingPhase != .claiming {
                    HomeProcessingCard(viewModel: viewModel)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }

                // Digital receipt hint
                DigitalReceiptHintCard()
                    .padding(.horizontal, 20)

                // Wallet Pass creator
                WalletPassCard {
                    showWalletPassCreator = true
                }
                .padding(.horizontal, 20)

                // Monthly lottery
                MonthlyLotteryCard()
                    .padding(.horizontal, 20)

                // Recent rewards
                RecentReceiptsSection(receipts: viewModel.recentReceipts)
                    .padding(.horizontal, 20)

                Spacer()
                    .frame(height: 120)
            }
            .padding(.top, 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
        .opacity(contentOpacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.processingPhase)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showMiloGame)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color(white: 0.05)

                LinearGradient(
                    stops: [
                        .init(color: headerBlueColor, location: 0.0),
                        .init(color: headerBlueColor.opacity(0.7), location: 0.25),
                        .init(color: headerBlueColor.opacity(0.3), location: 0.5),
                        .init(color: Color.clear, location: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.45 + geometry.safeAreaInsets.top)
                .frame(maxWidth: .infinity)
                .offset(y: -geometry.safeAreaInsets.top)
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Floating Scan Button

    private var floatingScanButton: some View {
        Button {
            if rateLimitManager.canUploadReceipt() {
                showCamera = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                showRateLimitAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.15, blue: 0.70),
                                deepPurple
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: deepPurple.opacity(0.5), radius: 12, y: 6)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(ScaleScanButtonStyle())
    }

    // MARK: - Profile Menu Button

    private var profileMenuButton: some View {
        Menu {
            Section {
                Button(action: {}) {
                    Label(rateLimitManager.usageDisplayString, systemImage: usageIconName)
                }
                .tint(usageColor)

                Button(action: {}) {
                    Label("\(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit) receipts", systemImage: receiptLimitIcon)
                }
                .tint(receiptLimitColor)
            }

            Section {
                Button {
                    showProfile = true
                } label: {
                    Label("Profile", systemImage: "person.fill")
                }
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 36, height: 36)

                Circle()
                    .fill(profileBadgeColor)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .offset(x: -2, y: -2)
            }
        }
    }

    // MARK: - Share Extension Detection

    private func checkForShareExtensionUploads() {
        processingManager.reloadPersistedReceipts()
        if processingManager.hasActiveProcessing && viewModel.processingPhase == .idle {
            viewModel.startProcessingForShareExtension()
        }
    }

    // MARK: - Usage Helpers

    private var usageIconName: String {
        let used = rateLimitManager.usagePercentage
        if used >= 0.95 { return "exclamationmark.bubble.fill" }
        else if used >= 0.8 { return "bubble.left.and.exclamationmark.bubble.right.fill" }
        else { return "bubble.left.fill" }
    }

    private var usageColor: Color {
        let used = rateLimitManager.usagePercentage
        return Color(red: 0.2 + (used * 0.7), green: 0.8 - (used * 0.6), blue: 0.2)
    }

    private var receiptLimitIcon: String {
        switch rateLimitManager.receiptLimitState {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .exhausted: return "xmark.circle.fill"
        }
    }

    private var receiptLimitColor: Color {
        switch rateLimitManager.receiptLimitState {
        case .normal: return .green
        case .warning: return .orange
        case .exhausted: return .red
        }
    }

    private var profileBadgeColor: Color {
        let receiptState = rateLimitManager.receiptLimitState
        let messageUsage = rateLimitManager.usagePercentage

        if receiptState == .exhausted || messageUsage >= 0.95 { return .red }
        if receiptState == .warning {
            if messageUsage >= 0.8 { return messageUsage >= 0.9 ? usageColor : .orange }
            return .orange
        }
        if messageUsage >= 0.8 { return usageColor }
        return .green
    }
}

// MARK: - Milo Dachshund Easter Egg

/// Tiny animated Milo dachshund using the same brand shapes/colors
/// from DachshundSniffingView. Tapping reveals the game inline.
private struct MiloDachshundEasterEgg: View {
    let onTap: () -> Void

    private let furBrown = Color(red: 0.60, green: 0.38, blue: 0.22)
    private let furDark = Color(red: 0.45, green: 0.26, blue: 0.14)
    private let furLight = Color(red: 0.70, green: 0.48, blue: 0.30)
    private let noseBlack = Color(red: 0.12, green: 0.10, blue: 0.08)

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 0) {
                Spacer()
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    MiniMiloDog(time: t)
                }
                .frame(width: 60, height: 32)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

/// Scaled-down Milo dachshund matching the brand mascot exactly.
private struct MiniMiloDog: View {
    let time: Double

    private let furBrown = Color(red: 0.60, green: 0.38, blue: 0.22)
    private let furDark = Color(red: 0.45, green: 0.26, blue: 0.14)
    private let furLight = Color(red: 0.70, green: 0.48, blue: 0.30)
    private let noseBlack = Color(red: 0.12, green: 0.10, blue: 0.08)

    var body: some View {
        let tailWag = sin(time * 10) * 12.0
        let walk = sin(time * 7) * 10.0
        let bob = abs(sin(time * 7)) * 1.0
        let earFlap = sin(time * 7) * 2.0

        ZStack {
            // Tail
            Capsule()
                .fill(furBrown.opacity(0.7))
                .frame(width: 2.5, height: 11)
                .rotationEffect(.degrees(-50 + tailWag * 0.8), anchor: .bottom)
                .offset(x: -20, y: -5 - bob)

            // Back legs
            RoundedRectangle(cornerRadius: 1.5)
                .fill(furDark.opacity(0.5))
                .frame(width: 4, height: 14)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: -13, y: 7 - bob)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(furDark.opacity(0.5))
                .frame(width: 4, height: 14)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: -9, y: 7 - bob)

            // Body
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [furLight, furBrown],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 42, height: 13)
                .rotationEffect(.degrees(3))
                .offset(y: -bob)

            // Belly shadow
            Capsule()
                .fill(furDark.opacity(0.15))
                .frame(width: 34, height: 3)
                .offset(y: 5 - bob)

            // Front legs
            RoundedRectangle(cornerRadius: 1.5)
                .fill(furBrown.opacity(0.8))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: 9, y: 10 - bob)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(furBrown.opacity(0.8))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: 13, y: 10 - bob)

            // Head (using ellipse to match brand head shape)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [furLight, furBrown],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 15, height: 14)
                .rotationEffect(.degrees(15))
                .offset(x: 22, y: 4 - bob)

            // Ear (floppy)
            Ellipse()
                .fill(furDark)
                .frame(width: 8, height: 14)
                .rotationEffect(.degrees(22 + earFlap), anchor: .top)
                .offset(x: 19, y: 1 - bob)

            // Snout
            Capsule()
                .fill(furBrown.opacity(0.9))
                .frame(width: 9, height: 5.5)
                .rotationEffect(.degrees(25))
                .offset(x: 28, y: 10 - bob)

            // Nose
            Ellipse()
                .fill(noseBlack)
                .frame(width: 4, height: 3)
                .offset(x: 30, y: 12 - bob)

            // Nose shine
            Ellipse()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1.5, height: 1)
                .offset(x: 30.5, y: 11 - bob)

            // Eye
            Circle()
                .fill(noseBlack)
                .frame(width: 2.5, height: 2.5)
                .offset(x: 24, y: 2 - bob)

            // Eye sparkle
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 1.2, height: 1.2)
                .offset(x: 24.5, y: 1.5 - bob)
        }
    }
}

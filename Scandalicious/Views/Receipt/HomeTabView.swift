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
    @ObservedObject private var processingManager = ReceiptProcessingManager.shared
    @ObservedObject private var gamificationManager = GamificationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var viewModel = HomeViewModel()
    @State private var showProfile = false

    @State private var contentOpacity: Double = 0
    @State private var showMiloGame = false
    @State private var showWalletPassCreator = false
    @State private var showGroceryList = false
    @ObservedObject private var groceryStore = GroceryListStore.shared
    @Environment(\.scenePhase) private var scenePhase

    private let headerBlueColor = Color(red: 0.04, green: 0.15, blue: 0.30)
    var body: some View {
        NavigationStack {
            ZStack {
                // Main scrollable content
                mainContent

            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    groceryListButton
                }
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
        .sheet(isPresented: $showGroceryList) {
            GroceryListSheet()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Milo dachshund easter egg (always visible when game not open)
                if !showMiloGame {
                    MiloDachshundEasterEgg {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            showMiloGame = true
                        }
                    }
                    .zIndex(1)
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

                // Multi-receipt processing cards
                if !processingManager.processingReceipts.isEmpty {
                    ProcessingReceiptsCard(
                        manager: processingManager,
                        onClaimReceipt: { receipt in
                            viewModel.claimReward(for: receipt)
                        }
                    )
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }

                // Recent uploaded receipts
                RecentUploadsSection(
                    receipts: viewModel.uploadedReceipts,
                    isLoading: viewModel.isLoadingReceipts,
                    onRefresh: { viewModel.loadUploadedReceipts() }
                )
                .padding(.horizontal, 20)

                Spacer()
                    .frame(height: 120)
            }
            .padding(.top, 0)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
        .opacity(contentOpacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: processingManager.processingReceipts.count)
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

    // MARK: - Grocery List Button

    private var groceryListButton: some View {
        GroceryListToolbarButton(count: groceryStore.activeItemCount) {
            showGroceryList = true
        }
    }

    // MARK: - Profile Menu Button

    private var profileMenuButton: some View {
        Menu {
            Button {
                showProfile = true
            } label: {
                Label("Profile", systemImage: "gearshape")
            }
            Button {
                showWalletPassCreator = true
            } label: {
                Label("Wallet Pass Creator", systemImage: "wallet.pass")
            }
        } label: {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                )
        }
    }

    // MARK: - Share Extension Detection

    private func checkForShareExtensionUploads() {
        processingManager.reloadPersistedReceipts()
    }

}

extension Notification.Name {
    static let switchToDealsTab = Notification.Name("app.switchToDealsTab")
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

//
//  ContentView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseAuth

// MARK: - Environment key for active tab (used by MiniBudgetRing to replay animation)

private struct SelectedTabIndexKey: EnvironmentKey {
    static let defaultValue: Int = 1 // scan tab by default
}

extension EnvironmentValues {
    var selectedTabIndex: Int {
        get { self[SelectedTabIndexKey.self] }
        set { self[SelectedTabIndexKey.self] = newValue }
    }
}

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var transactionManager = TransactionManager()
    @StateObject private var dataManager = StoreDataManager()
    @State private var selectedTab: Tab = .home
    @State private var showSignOutConfirmation = false
    @State private var hasLoadedInitialData = false

    // Gamification reward overlay (global, across all tabs)
    @State private var showRewardCelebration = false
    @State private var currentRewardEvent: RewardEvent? = nil

    enum Tab: Int, Hashable {
        case budget = 0
        case home = 1
        case promos = 2
        case dobby = 3
        case rewards = 4
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ViewTab(showSignOutConfirmation: $showSignOutConfirmation, dataManager: dataManager)
                    .tabItem {
                        Label(L("tab_budget"), systemImage: "wallet.bifold.fill")
                    }
                    .tag(Tab.budget)

                ScanTab()
                    .tabItem {
                        Label(L("tab_home"), systemImage: "house.fill")
                    }
                    .tag(Tab.home)

                PromosTab()
                    .tabItem {
                        Label("Deals", systemImage: "tag.fill")
                    }
                    .tag(Tab.promos)

                ScandaLiciousTab()
                    .tabItem {
                        Label {
                            Text(L("tab_milo"))
                        } icon: {
                            MiloTabIcon()
                        }
                    }
                    .tag(Tab.dobby)

                RewardsTab()
                    .tabItem {
                        Label("Rewards", systemImage: "gift.fill")
                    }
                    .tag(Tab.rewards)
            }
            .tint(.blue) // Apple blue
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
            .environment(\.selectedTabIndex, selectedTab.rawValue)

            // Loading screen overlay
            if !hasLoadedInitialData {
                SyncLoadingView()
                    .transition(.opacity)
            }

            // Reward celebration overlay (visible across all tabs)
            if showRewardCelebration, let event = currentRewardEvent {
                RewardCelebrationView(event: event) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showRewardCelebration = false
                    }
                    currentRewardEvent = nil
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasLoadedInitialData)
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { notification in
            let storeName = notification.userInfo?["storeName"] as? String
            let receiptAmount = notification.userInfo?["receiptAmount"] as? Double
            let event = GamificationManager.shared.awardReceiptReward(
                storeName: storeName,
                receiptAmount: receiptAmount
            )
            currentRewardEvent = event
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showRewardCelebration = true
                }
            }
        }
        .environmentObject(transactionManager)
        .environmentObject(dataManager)
        .preferredColorScheme(.dark)
        .onAppear {
            // Configure data manager on first appear
            if !hasLoadedInitialData {
                dataManager.configure(with: transactionManager)
                Task {
                    await loadAllData()
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
        }
        .confirmationDialog(L("sign_out"), isPresented: $showSignOutConfirmation) {
            Button(L("sign_out"), role: .destructive) {
                do {
                    try authManager.signOut()
                } catch {
                }
            }
            Button(L("cancel"), role: .cancel) {}
        } message: {
            Text(L("sign_out_confirm"))
        }
    }

    // MARK: - Full Data Loading

    /// Fetches period metadata and current month breakdowns from the backend,
    /// then dismisses the loading screen.
    private func loadAllData() async {
        await dataManager.fetchPeriodMetadata()

        guard !dataManager.periodMetadata.isEmpty else {
            await MainActor.run { hasLoadedInitialData = true }
            return
        }

        // Load the current (most recent) period's store breakdowns
        if let currentPeriod = dataManager.periodMetadata.first?.period {
            await dataManager.fetchPeriodDetails(currentPeriod)
        }

        await MainActor.run { hasLoadedInitialData = true }
    }
}

// MARK: - View Tab
struct ViewTab: View {
    @Binding var showSignOutConfirmation: Bool
    @ObservedObject var dataManager: StoreDataManager

    var body: some View {
        NavigationStack {
            OverviewView(dataManager: dataManager, showSignOutConfirmation: $showSignOutConfirmation)
                .navigationBarTitleDisplayMode(.inline)
        }
        .id("ViewTab") // Prevent recreation
    }
}

// MARK: - Scan Tab
struct ScanTab: View {
    var body: some View {
        ReceiptScanView()
            .id("ScanTab") // Prevent recreation
    }
}

// MARK: - Promos Tab
struct PromosTab: View {
    @StateObject private var viewModel = PromosViewModel()

    var body: some View {
        NavigationStack {
            PromosView(viewModel: viewModel)
        }
        .id("PromosTab") // Prevent recreation
    }
}

// MARK: - ScandaLicious Tab
struct ScandaLiciousTab: View {
    var body: some View {
        NavigationStack {
            ScandaLiciousAIChatView()
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .id("ScandaLiciousTab") // Prevent recreation
    }

    private var syncingStatusBanner: some View {
        HStack(spacing: 6) {
            SyncingArrowsView()
            Text(L("syncing"))
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.blue)
        .padding(.top, 12)
    }

    private var syncedStatusBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 11))
            Text(L("synced"))
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.top, 12)
    }
}

// MARK: - Rewards Tab
struct RewardsTab: View {
    var body: some View {
        NavigationStack {
            RewardsView()
        }
        .id("RewardsTab")
    }
}

// MARK: - Milo Tab Icon

/// Tiny Dachshund head for the tab bar, rendered as a template image
/// so iOS can apply the correct tint for selected/unselected states.
private struct MiloTabIcon: View {
    var body: some View {
        Image(uiImage: renderTabIcon())
            .renderingMode(.template)
    }

    private func renderTabIcon() -> UIImage {
        let size: CGFloat = 28
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let gc = ctx.cgContext
            let u = size / 100
            let cx = size / 2
            let cy = size / 2

            gc.setFillColor(UIColor.black.cgColor)

            // Left ear (large floppy)
            gc.beginPath()
            gc.move(to: CGPoint(x: cx - 18 * u, y: cy - 16 * u))
            gc.addCurve(
                to: CGPoint(x: cx - 50 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx - 28 * u, y: cy - 34 * u),
                control2: CGPoint(x: cx - 48 * u, y: cy - 32 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 44 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx - 58 * u, y: cy - 2 * u),
                control2: CGPoint(x: cx - 56 * u, y: cy + 20 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 32 * u, y: cy + 26 * u),
                control1: CGPoint(x: cx - 40 * u, y: cy + 34 * u),
                control2: CGPoint(x: cx - 36 * u, y: cy + 34 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 18 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx - 26 * u, y: cy + 10 * u),
                control2: CGPoint(x: cx - 14 * u, y: cy - 4 * u)
            )
            gc.closePath()
            gc.fillPath()

            // Right ear (large floppy)
            gc.beginPath()
            gc.move(to: CGPoint(x: cx + 18 * u, y: cy - 16 * u))
            gc.addCurve(
                to: CGPoint(x: cx + 50 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx + 28 * u, y: cy - 34 * u),
                control2: CGPoint(x: cx + 48 * u, y: cy - 32 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 44 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx + 58 * u, y: cy - 2 * u),
                control2: CGPoint(x: cx + 56 * u, y: cy + 20 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 32 * u, y: cy + 26 * u),
                control1: CGPoint(x: cx + 40 * u, y: cy + 34 * u),
                control2: CGPoint(x: cx + 36 * u, y: cy + 34 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 18 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx + 26 * u, y: cy + 10 * u),
                control2: CGPoint(x: cx + 14 * u, y: cy - 4 * u)
            )
            gc.closePath()
            gc.fillPath()

            // Head (cute dog shape)
            gc.beginPath()
            gc.move(to: CGPoint(x: cx, y: cy - 32 * u))
            gc.addCurve(
                to: CGPoint(x: cx + 36 * u, y: cy - 6 * u),
                control1: CGPoint(x: cx + 16 * u, y: cy - 32 * u),
                control2: CGPoint(x: cx + 32 * u, y: cy - 22 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 18 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx + 36 * u, y: cy + 10 * u),
                control2: CGPoint(x: cx + 28 * u, y: cy + 26 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 18 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx + 8 * u, y: cy + 34 * u),
                control2: CGPoint(x: cx - 8 * u, y: cy + 34 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 36 * u, y: cy - 6 * u),
                control1: CGPoint(x: cx - 28 * u, y: cy + 26 * u),
                control2: CGPoint(x: cx - 36 * u, y: cy + 10 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx, y: cy - 32 * u),
                control1: CGPoint(x: cx - 32 * u, y: cy - 22 * u),
                control2: CGPoint(x: cx - 16 * u, y: cy - 32 * u)
            )
            gc.closePath()
            gc.fillPath()

            // Snout (lighter — leave as filled, template mode handles tint)
            gc.fillEllipse(in: CGRect(x: cx - 20 * u, y: cy + 2 * u, width: 40 * u, height: 30 * u))

            // Cut out eyes (white = transparent in template mode)
            gc.setBlendMode(.clear)

            // Left eye
            gc.fillEllipse(in: CGRect(
                x: cx - 14 * u - 7 * u, y: cy - 8 * u - 8 * u,
                width: 14 * u, height: 16 * u
            ))
            // Right eye
            gc.fillEllipse(in: CGRect(
                x: cx + 14 * u - 7 * u, y: cy - 8 * u - 8 * u,
                width: 14 * u, height: 16 * u
            ))

            // Nose cutout
            gc.fillEllipse(in: CGRect(
                x: cx - 7 * u, y: cy + 4 * u,
                width: 14 * u, height: 10 * u
            ))

            gc.setBlendMode(.normal)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}

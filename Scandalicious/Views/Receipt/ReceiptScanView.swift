//
//  ReceiptScanView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI
import StoreKit

struct ReceiptScanView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject private var rateLimitManager = RateLimitManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var receiptsViewModel = ReceiptsViewModel()
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var errorMessage: String?
    @State private var errorTitle: String = "Upload Failed"
    @State private var showError = false
    @State private var uploadState: ReceiptUploadState = .idle
    @State private var uploadedReceipt: ReceiptUploadResponse?
    @State private var showReceiptDetails = false
    @State private var canRetryAfterError = false
    @State private var showRateLimitAlert = false
    @State private var showCaptureSuccess = false
    @State private var showProfile = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastCheckedUploadTimestamp: TimeInterval = 0

    // Syncing status for top banner
    @State private var isSyncing = false
    @State private var isTabVisible = false

    // Recent receipt tracking
    @State private var recentReceipt: ReceiptUploadResponse?
    @State private var showRecentReceiptDetails = false
    @State private var isRecentReceiptExpanded = false

    // Total receipts count (all time)
    @State private var totalReceiptsScanned: Int = 0

    // Total items scanned (all time)
    @State private var totalItemsScanned: Int = 0

    // Top stores stats (top 3)
    @State private var topStores: [(name: String, visits: Int)] = []

    // Top categories (all time) for flippable card
    @State private var topCategories: [TopCategory] = []
    @State private var isTopStoresCardFlipped = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                mainContentView

                // Capture success overlay
                if showCaptureSuccess {
                    CaptureSuccessOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                // Floating scan button (bottom right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingScanButton
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
            }
            .toolbar {
                // Profile button - trailing (right side)
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileMenuButton
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTabVisible = true
                }
            }
            loadTotalReceiptsCount()
            loadAllTimeStats()
        }
        .onDisappear {
            isTabVisible = false
        }
        .receiptErrorOverlay(
            isPresented: $showError,
            title: errorTitle,
            message: errorMessage ?? "Failed to process receipt",
            onRetry: canRetryAfterError ? {
                errorMessage = nil
                errorTitle = "Upload Failed"
                capturedImage = nil
                uploadState = .idle
                canRetryAfterError = false
                showCamera = true
            } : nil
        )
        .fullScreenCover(isPresented: $showCamera) {
            CustomCameraView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showReceiptDetails) {
            showReceiptDetails = false
            // Keep recent receipt for display
        } content: {
            if let receipt = uploadedReceipt {
                ReceiptDetailsView(receipt: receipt) {
                    // Receipt was deleted - notify to refresh data
                    NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                    recentReceipt = nil
                }
            }
        }
        .sheet(isPresented: $showRecentReceiptDetails) {
            if let receipt = recentReceipt {
                ReceiptDetailsView(receipt: receipt) {
                    NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                    recentReceipt = nil
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .environmentObject(authManager)
                    .environmentObject(subscriptionManager)
            }
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                // Double-check rate limit before processing (could have changed while camera was open)
                if rateLimitManager.canUploadReceipt() {
                    // Show success overlay first
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showCaptureSuccess = true
                    }

                    // Hide after delay and start processing
                    Task {
                        try? await Task.sleep(for: .seconds(2.2))
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.4)) {
                                showCaptureSuccess = false
                            }
                        }
                        await processReceipt(image: image)
                    }
                } else {
                    capturedImage = nil
                    showRateLimitAlert = true
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }
        .alert("Upload Limit Reached", isPresented: $showRateLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rateLimitManager.receiptLimitMessage ?? "You've used all your receipt uploads for this month. Your limit will reset soon.")
        }
        .onAppear {
            print("👁️ [ScanTab] onAppear - view appeared")
            // Initialize lastCheckedUploadTimestamp to current value to avoid retriggering old uploads
            initializeLastCheckedTimestamp()
            // Sync rate limit when view appears to ensure we have latest count
            Task {
                print("🔄 [ScanTab] onAppear - syncing rate limit...")
                await rateLimitManager.syncFromBackend()
                print("✅ [ScanTab] onAppear - sync complete. Receipts: \(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit)")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Check for share extension uploads when app becomes active
            if newPhase == .active {
                print("🔄 [ScanTab] scenePhase changed to active")
                checkForShareExtensionUploads()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Early notification when app is about to enter foreground
            print("🔄 [ScanTab] App will enter foreground")
            checkForShareExtensionUploads()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Backup: Also check when app becomes active via notification (more reliable)
            print("🔄 [ScanTab] App became active (UIApplication notification)")
            checkForShareExtensionUploads()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
            // Refresh total count when a receipt is uploaded
            loadTotalReceiptsCount()
        }
        .animation(.easeInOut, value: uploadState)
    }

    // MARK: - Floating Scan Button

    // Deep purple color matching overview tab theme
    private var deepPurple: Color {
        Color(red: 0.35, green: 0.10, blue: 0.60)
    }

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
            // Usage & Subscription
            Section {
                // Message rate limit usage display with smart color
                Button(action: {}) {
                    Label(rateLimitManager.usageDisplayString, systemImage: usageIconName)
                }
                .tint(usageColor)

                // Receipt upload limit
                Button(action: {}) {
                    Label("\(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit) receipts", systemImage: receiptLimitIcon)
                }
                .tint(receiptLimitColor)
            }

            // Profile
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

    // MARK: - Usage Display Helpers

    private var usageIconName: String {
        let used = rateLimitManager.usagePercentage
        if used >= 0.95 {
            return "exclamationmark.bubble.fill"
        } else if used >= 0.8 {
            return "bubble.left.and.exclamationmark.bubble.right.fill"
        } else {
            return "bubble.left.fill"
        }
    }

    private var usageColor: Color {
        let used = rateLimitManager.usagePercentage
        let red = 0.2 + (used * 0.7)
        let green = 0.8 - (used * 0.6)
        let blue = 0.2
        return Color(red: red, green: green, blue: blue)
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

        if receiptState == .exhausted || messageUsage >= 0.95 {
            return .red
        }
        if receiptState == .warning {
            if messageUsage >= 0.8 {
                return messageUsage >= 0.9 ? usageColor : .orange
            }
            return .orange
        }
        if messageUsage >= 0.8 {
            return usageColor
        }
        return usageColor
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Syncing banner at top
                if isTabVisible && (isSyncing || rateLimitManager.isReceiptUploading) {
                    syncingStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                } else if isTabVisible && rateLimitManager.showReceiptSynced {
                    syncedStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }

                // Stats Section (includes Recent Scan card between Top Stores and Scans Remaining)
                statsSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Share tip card
                shareHintCard
                    .padding(.horizontal, 20)

                // Bottom spacing for floating button
                Color.clear
                    .frame(height: 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.05))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSyncing)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.isReceiptUploading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.showReceiptSynced)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 12) {
            // Hero stats row: Receipts & Items
            HStack(spacing: 12) {
                heroReceiptsCard
                totalItemsCard
            }

            // Top 3 Stores card
            topStoresCard

            // Recent Receipt Card (if exists) - positioned between Top Stores and Scans Remaining
            if let receipt = recentReceipt {
                recentReceiptCard(receipt: receipt)
            }

            // Remaining quota pill
            remainingQuotaPill
        }
    }

    // MARK: - Hero Receipts Card

    private var heroReceiptsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [deepPurple.opacity(0.3), Color.blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Value
            Text("\(totalReceiptsScanned)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            // Label
            Text("Receipts Scanned")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 125)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))

                // Gradient accent
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [deepPurple.opacity(0.15), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Total Items Card

    private var totalItemsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 38, height: 38)

                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }

            Spacer()

            // Value
            Text("\(totalItemsScanned)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            // Label
            Text("Items Tracked")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 125)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))

                // Subtle gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.08), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Top Stores Card (Flippable)

    @State private var flipDegrees: Double = 0

    private var topStoresCard: some View {
        ZStack {
            // Back side - Top Categories
            topCategoriesCardContent
                .opacity(isTopStoresCardFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0, y: 1, z: 0)
                )

            // Front side - Top Stores
            topStoresCardContent
                .opacity(isTopStoresCardFlipped ? 0 : 1)
        }
        .rotation3DEffect(
            .degrees(flipDegrees),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isTopStoresCardFlipped.toggle()
                flipDegrees += 180
            }
        }
    }

    // Front side content - Top Stores
    private var topStoresCardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                }

                Text("Top Stores")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Flip hint
                if !topCategories.isEmpty {
                    HStack(spacing: 4) {
                        Text("Tap for categories")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }

            // Stores list
            if topStores.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "storefront")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No stores yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topStores.enumerated()), id: \.offset) { index, store in
                        topStoreRow(rank: index + 1, name: store.name, visits: store.visits)
                    }
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))

                // Subtle gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.06), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // Back side content - Top Categories
    private var topCategoriesCardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.purple)
                }

                Text("Top Categories")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Flip hint
                HStack(spacing: 4) {
                    Text("Tap for stores")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            // Categories list
            if topCategories.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No categories yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topCategories.prefix(3).enumerated()), id: \.offset) { index, category in
                        topCategoryRow(rank: index + 1, category: category)
                    }
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))

                // Subtle gradient (purple theme)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.06), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Top Category Row

    private func topCategoryRow(rank: Int, category: TopCategory) -> some View {
        let medalColor = rankColor(for: rank)
        let medalGradient = rankGradient(for: rank)

        return HStack(spacing: 14) {
            // Rank medal badge
            ZStack {
                // Medal background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: medalGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                // Rank number
                Text("\(rank)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Category icon
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(medalColor)
                .frame(width: 24)

            // Category name
            Text(category.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Spent amount with label
            VStack(alignment: .trailing, spacing: 2) {
                Text("€\(category.totalSpent, specifier: "%.0f")")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(medalColor)
                Text("spent")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Base fill with medal tint
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                medalColor.opacity(0.12),
                                medalColor.opacity(0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [
                            medalColor.opacity(0.4),
                            medalColor.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Top Store Row

    private func topStoreRow(rank: Int, name: String, visits: Int) -> some View {
        let medalColor = rankColor(for: rank)
        let medalGradient = rankGradient(for: rank)

        return HStack(spacing: 14) {
            // Rank medal badge
            ZStack {
                // Medal background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: medalGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                // Rank number
                Text("\(rank)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Store name
            Text(name.localizedCapitalized)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Visits count with label
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(visits)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(medalColor)
                Text("visits")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Base fill with medal tint
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                medalColor.opacity(0.12),
                                medalColor.opacity(0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [
                            medalColor.opacity(0.4),
                            medalColor.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Rank Color

    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.8) // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.2) // Bronze
        default: return Color.cyan
        }
    }

    // MARK: - Rank Gradient

    private func rankGradient(for rank: Int) -> [Color] {
        switch rank {
        case 1: // Gold - rich metallic gradient
            return [
                Color(red: 1.0, green: 0.88, blue: 0.35),
                Color(red: 0.95, green: 0.75, blue: 0.0),
                Color(red: 0.80, green: 0.60, blue: 0.0)
            ]
        case 2: // Silver - sleek metallic gradient
            return [
                Color(red: 0.85, green: 0.85, blue: 0.90),
                Color(red: 0.70, green: 0.70, blue: 0.75),
                Color(red: 0.55, green: 0.55, blue: 0.60)
            ]
        case 3: // Bronze - warm metallic gradient
            return [
                Color(red: 0.90, green: 0.60, blue: 0.35),
                Color(red: 0.75, green: 0.45, blue: 0.20),
                Color(red: 0.60, green: 0.35, blue: 0.15)
            ]
        default:
            return [Color.cyan, Color.cyan.opacity(0.7)]
        }
    }

    // MARK: - Remaining Quota Pill

    private var remainingQuotaPill: some View {
        HStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(rateLimitManager.receiptsRemaining) / CGFloat(max(rateLimitManager.receiptsLimit, 1)))
                    .stroke(
                        receiptLimitColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(rateLimitManager.receiptsRemaining)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(receiptLimitColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Scans Remaining")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Resets monthly")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // Limit badge
            Text("\(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(receiptLimitColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(receiptLimitColor.opacity(0.12))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Recent Receipt Card

    private func recentReceiptCard(receipt: ReceiptUploadResponse) -> some View {
        ExpandableReceiptCard(
            receipt: receipt,
            isExpanded: isRecentReceiptExpanded,
            onTap: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isRecentReceiptExpanded.toggle()
                }
            },
            onDelete: {
                Task {
                    do {
                        try await AnalyticsAPIService.shared.removeReceipt(receiptId: receipt.receiptId)
                        NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                        withAnimation {
                            recentReceipt = nil
                            isRecentReceiptExpanded = false
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            },
            onDeleteItem: { receiptId, itemId in
                deleteRecentReceiptItem(receiptId: receiptId, itemId: itemId)
            },
            accentColor: .green,
            badgeText: "Recent Scan",
            showDate: false,
            showItemCount: false
        )
    }

    // MARK: - Delete Recent Receipt Item

    private func deleteRecentReceiptItem(receiptId: String, itemId: String) {
        Task {
            do {
                let response = try await AnalyticsAPIService.shared.removeReceiptItem(receiptId: receiptId, itemId: itemId)

                await MainActor.run {
                    // Check if backend indicates the entire receipt was deleted
                    if response.receiptDeleted == true {
                        withAnimation {
                            recentReceipt = nil
                            isRecentReceiptExpanded = false
                        }
                        NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                    } else if var receipt = recentReceipt {
                        // Remove the item from local state
                        let updatedTransactions = receipt.transactions.filter { $0.itemId != itemId }

                        if updatedTransactions.isEmpty {
                            // No items left, remove the receipt
                            withAnimation {
                                recentReceipt = nil
                                isRecentReceiptExpanded = false
                            }
                            NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                        } else {
                            // Update receipt with remaining items
                            let newTotal = response.updatedTotalAmount ?? updatedTransactions.reduce(0) { $0 + $1.itemPrice }
                            let newHealthScore = response.updatedAverageHealthScore ?? {
                                let scores = updatedTransactions.compactMap { $0.healthScore }
                                guard !scores.isEmpty else { return nil as Double? }
                                return Double(scores.reduce(0, +)) / Double(scores.count)
                            }()

                            withAnimation {
                                recentReceipt = ReceiptUploadResponse(
                                    receiptId: receipt.receiptId,
                                    status: receipt.status,
                                    storeName: receipt.storeName,
                                    receiptDate: receipt.receiptDate,
                                    totalAmount: newTotal,
                                    itemsCount: response.updatedItemsCount ?? updatedTransactions.count,
                                    transactions: updatedTransactions,
                                    warnings: receipt.warnings,
                                    averageHealthScore: newHealthScore,
                                    isDuplicate: receipt.isDuplicate,
                                    duplicateScore: receipt.duplicateScore
                                )
                            }
                        }

                        // Notify other views to refresh
                        NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)
                    }
                }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    // MARK: - Share Hint Card

    private var shareHintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.85, green: 0.2, blue: 0.6))

            VStack(alignment: .leading, spacing: 3) {
                Text("Got a digital receipt?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Use the Share button from any app")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Syncing Status Banners

    private var syncingStatusBanner: some View {
        HStack(spacing: 10) {
            // Spinning arrow animation
            ScanSyncingArrowView()

            Text("Syncing")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var syncedStatusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("Synced")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.green)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Load Stats

    /// Load all-time stats from the new backend endpoint
    /// Falls back to the old multi-request approach if the new endpoint isn't available yet
    private func loadTotalReceiptsCount() {
        // Now handled by loadAllTimeStats() via the new /analytics/all-time endpoint
        // Keeping this method for backwards compatibility during transition
    }

    private func loadAllTimeStats() {
        Task {
            do {
                // Try the new unified all-time stats endpoint first
                // Request more stores/categories for the flippable card
                let allTimeStats = try await AnalyticsAPIService.shared.getAllTimeStats(
                    topStoresLimit: 5,
                    topCategoriesLimit: 5
                )

                await MainActor.run {
                    totalReceiptsScanned = allTimeStats.totalReceipts
                    totalItemsScanned = allTimeStats.totalItems
                    topStores = allTimeStats.top3StoresByVisits
                    topCategories = allTimeStats.topCategories ?? []
                }
            } catch {
                // Fallback to old multi-request approach if new endpoint not available
                print("New /analytics/all-time endpoint not available, falling back to legacy approach: \(error)")
                await loadAllTimeStatsLegacy()
            }
        }
    }

    /// Legacy method: Load all-time stats using multiple API calls
    /// Used as fallback when /analytics/all-time endpoint is not yet implemented
    private func loadAllTimeStatsLegacy() async {
        do {
            // Get all-time receipts count by fetching with no date filter
            async let receiptsTask = AnalyticsAPIService.shared.fetchReceipts(filters: ReceiptFilters(page: 1, pageSize: 1))

            // Fetch all-time period metadata to get total items
            async let periodsTask = AnalyticsAPIService.shared.fetchPeriods(periodType: .month, numPeriods: 52)

            // Fetch summary to get top stores (all-time)
            async let summaryTask = AnalyticsAPIService.shared.fetchSummary(filters: AnalyticsFilters(period: .year, numPeriods: 10))

            // Await all in parallel
            let (receiptsResponse, periodsResponse, summaryResponse) = try await (receiptsTask, periodsTask, summaryTask)

            // Sum up total items across all periods
            let totalItems = periodsResponse.periods.compactMap { $0.totalItems }.reduce(0, +)

            // Get top 3 stores by visits
            let sortedStores = (summaryResponse.stores ?? [])
                .sorted { $0.storeVisits > $1.storeVisits }
                .prefix(3)
                .map { (name: $0.storeName, visits: $0.storeVisits) }

            await MainActor.run {
                totalReceiptsScanned = receiptsResponse.total
                totalItemsScanned = totalItems
                topStores = Array(sortedStores)
            }
        } catch {
            print("Failed to load all-time stats (legacy): \(error)")
        }
    }

    // MARK: - Process Receipt

    private func processReceipt(image: UIImage) async {
        guard uploadState == .idle else {
            print("Already processing, skipping")
            return
        }

        // Check image quality
        let qualityChecker = ReceiptQualityChecker()
        let qualityResult = await qualityChecker.checkQuality(of: image)

        print("📊 Quality Check: Score \(String(format: "%.1f%%", qualityResult.qualityScore * 100))")

        guard qualityResult.isAcceptable else {
            await MainActor.run {
                capturedImage = nil
                canRetryAfterError = true

                var message = ""
                if !qualityResult.issues.isEmpty {
                    for issue in qualityResult.issues {
                        message += "• \(issue.rawValue)\n"
                    }
                    message += "\n"
                }
                message += "Tips: Good lighting, hold steady, capture entire receipt"

                errorTitle = "Quality Check Failed"
                errorMessage = message
                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            return
        }

        // Upload receipt
        await MainActor.run {
            uploadState = .uploading
            isSyncing = true
            // Notify View tab to show syncing indicator
            NotificationCenter.default.post(name: .receiptUploadStarted, object: nil)
        }

        do {
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)

            // Debug logging for duplicate detection
            print("📬 Receipt upload response:")
            print("   Status: \(response.status.rawValue)")
            print("   Store: \(response.storeName ?? "N/A")")
            print("   Items: \(response.itemsCount)")
            print("   Is Duplicate: \(response.isDuplicate)")
            if let score = response.duplicateScore {
                print("   Duplicate Score: \(String(format: "%.1f%%", score * 100))")
            }
            if response.isDuplicate {
                print("   ⚠️ DUPLICATE RECEIPT DETECTED - items not saved")
            }

            await MainActor.run {
                capturedImage = nil
                isSyncing = false

                switch response.status {
                case .success, .completed:
                    uploadState = .success(response)
                    uploadedReceipt = response
                    recentReceipt = response  // Save for recent receipt card

                    // Optimistically update rate limit counter
                    rateLimitManager.decrementReceiptLocal()

                    // Update total receipts count
                    totalReceiptsScanned += 1

                    NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await MainActor.run {
                            uploadState = .idle
                        }
                    }

                case .pending, .processing:
                    uploadState = .processing
                    canRetryAfterError = true
                    errorMessage = "Receipt is still being processed. Please check back later."
                    showError = true
                    uploadState = .idle
                    // Clear syncing indicator in View tab
                    NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)

                case .failed:
                    uploadState = .failed("Receipt processing failed")
                    canRetryAfterError = true
                    errorMessage = "The receipt could not be processed. Please try again."
                    showError = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    // Clear syncing indicator in View tab
                    NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)
                }
            }
        } catch let error as ReceiptUploadError {
            await MainActor.run {
                uploadState = .failed(error.localizedDescription)
                isSyncing = false

                // Handle rate limit exceeded specially
                if case .rateLimitExceeded = error {
                    canRetryAfterError = false // Can't retry - need to wait
                    errorMessage = error.rateLimitUserMessage ?? "Upload limit reached for this month."

                    // Also sync rate limit manager
                    Task {
                        await RateLimitManager.shared.syncFromBackend()
                    }
                } else {
                    canRetryAfterError = true
                    errorMessage = error.localizedDescription
                }

                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                // Clear syncing indicator in View tab
                NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)
            }
        } catch {
            await MainActor.run {
                uploadState = .failed(error.localizedDescription)
                isSyncing = false
                canRetryAfterError = true
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                // Clear syncing indicator in View tab
                NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)
            }
        }
    }

    // MARK: - Share Extension Upload Detection

    /// Initialize the last checked timestamp from persisted storage
    private func initializeLastCheckedTimestamp() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            // First try to load from persisted lastCheckedUploadTimestamp
            let persistedLastChecked = sharedDefaults.double(forKey: "lastCheckedUploadTimestamp")
            if persistedLastChecked > 0 {
                lastCheckedUploadTimestamp = persistedLastChecked
                print("📋 [ScanTab] Restored lastCheckedUploadTimestamp from storage: \(persistedLastChecked)")
            } else {
                // Fall back to current upload timestamp to prevent detecting old uploads as new
                let existingTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
                if existingTimestamp > 0 {
                    lastCheckedUploadTimestamp = existingTimestamp
                    // Also persist it so future checks use this value
                    sharedDefaults.set(existingTimestamp, forKey: "lastCheckedUploadTimestamp")
                    print("📋 [ScanTab] Initialized lastCheckedUploadTimestamp to current upload timestamp: \(existingTimestamp)")
                }
            }
        }
    }

    /// Checks if the Share Extension uploaded a receipt while the app was in the background
    private func checkForShareExtensionUploads() {
        print("🔍 [ScanTab] checkForShareExtensionUploads() called")

        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ [ScanTab] Could not access shared UserDefaults with App Group: \(appGroupIdentifier)")
            return
        }
        print("✅ [ScanTab] Successfully accessed shared UserDefaults")

        // Check if there's a new upload timestamp
        let uploadTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
        print("🔍 [ScanTab] Checking for Share Extension uploads:")
        print("   Timestamp from shared defaults: \(uploadTimestamp)")
        print("   Last checked timestamp: \(lastCheckedUploadTimestamp)")
        print("   Is new upload: \(uploadTimestamp > lastCheckedUploadTimestamp && uploadTimestamp > 0)")

        // If there's a new upload (timestamp is newer than last checked)
        if uploadTimestamp > lastCheckedUploadTimestamp && uploadTimestamp > 0 {
            print("📬 [ScanTab] NEW Share Extension upload detected!")

            // Update last checked timestamp and persist it
            lastCheckedUploadTimestamp = uploadTimestamp
            sharedDefaults.set(uploadTimestamp, forKey: "lastCheckedUploadTimestamp")

            // Post notification so Overview tab shows syncing indicator
            NotificationCenter.default.post(name: .shareExtensionUploadDetected, object: nil)

            // Optimistically decrement the local rate limit counter
            // This is a workaround for the backend rate-limit API returning 403
            print("📉 [ScanTab] Optimistically decrementing rate limit counter")
            rateLimitManager.decrementReceiptLocal()
            print("✅ [ScanTab] Rate limit updated. Receipts: \(rateLimitManager.receiptsUsed)/\(rateLimitManager.receiptsLimit) used, \(rateLimitManager.receiptsRemaining) remaining")
        } else {
            print("ℹ️ [ScanTab] No new Share Extension upload detected")
        }
    }
}

// MARK: - Capture Success Overlay

struct CaptureSuccessOverlay: View {
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var innerGlowOpacity: Double = 0
    @State private var checkmarkRotation: Double = -30

    private let accentColor = Color(red: 0.2, green: 0.8, blue: 0.4)

    var body: some View {
        ZStack {
            // Semi-transparent background with subtle gradient
            LinearGradient(
                colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Premium animation layer
            PremiumSuccessAnimation()
                .allowsHitTesting(false)

            // Success card
            VStack(spacing: 24) {
                // Animated checkmark with glow
                ZStack {
                    // Soft glow behind checkmark
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    accentColor.opacity(0.4),
                                    accentColor.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .opacity(innerGlowOpacity)
                        .blur(radius: 10)

                    // Main circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.85, blue: 0.5),
                                    accentColor,
                                    Color(red: 0.15, green: 0.7, blue: 0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: accentColor.opacity(0.5), radius: 16, y: 4)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)

                    // Checkmark icon
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(checkmarkScale)
                        .rotationEffect(.degrees(checkmarkRotation))
                        .opacity(checkmarkOpacity)
                }

                // Done text with subtle styling
                Text("Done")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(cardOpacity)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 44)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 15)
            )
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
            // Card fade in
            withAnimation(.easeOut(duration: 0.4)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }

            // Checkmark animation with spring
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
                checkmarkRotation = 0
            }

            // Inner glow fade in
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                innerGlowOpacity = 1.0
            }

            // Subtle glow pulse
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.6)) {
                innerGlowOpacity = 0.6
            }
        }
    }
}

// MARK: - Premium Success Animation

struct PremiumSuccessAnimation: View {
    @State private var rings: [RingData] = []
    @State private var particles: [ShimmerParticle] = []
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8

    private let accentColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    private let secondaryColor = Color(red: 0.3, green: 0.6, blue: 0.9)

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // Ambient glow backdrop
                RadialGradient(
                    colors: [
                        accentColor.opacity(0.3),
                        accentColor.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .position(center)
                .blur(radius: 40)

                // Expanding rings
                ForEach(rings) { ring in
                    PremiumRingView(data: ring)
                        .position(center)
                }

                // Shimmer particles
                ForEach(particles) { particle in
                    ShimmerParticleView(data: particle, center: center)
                }
            }
            .onAppear {
                startAnimation(screenSize: geometry.size)
            }
        }
        .ignoresSafeArea()
    }

    private func startAnimation(screenSize: CGSize) {
        // Animate glow
        withAnimation(.easeOut(duration: 0.6)) {
            glowOpacity = 1
            glowScale = 1.2
        }

        withAnimation(.easeInOut(duration: 1.6).delay(0.6)) {
            glowOpacity = 0.4
        }

        // Create expanding rings with staggered timing
        var ringData: [RingData] = []
        for i in 0..<3 {
            ringData.append(RingData(
                id: i,
                delay: Double(i) * 0.15,
                maxScale: 2.5 + Double(i) * 0.5,
                duration: 1.1 + Double(i) * 0.2,
                strokeWidth: 2.0 - Double(i) * 0.5
            ))
        }
        rings = ringData

        // Create shimmer particles
        var particleData: [ShimmerParticle] = []
        for i in 0..<24 {
            let angle = (Double(i) / 24.0) * 2 * .pi
            let distance = CGFloat.random(in: 80...180)
            let wave = i % 3

            particleData.append(ShimmerParticle(
                id: i,
                angle: angle,
                distance: distance,
                size: CGFloat.random(in: 2...5),
                delay: Double(wave) * 0.1 + Double.random(in: 0...0.2),
                duration: Double.random(in: 1.3...1.9)
            ))
        }
        particles = particleData
    }
}

// MARK: - Ring Data

struct RingData: Identifiable {
    let id: Int
    let delay: Double
    let maxScale: Double
    let duration: Double
    let strokeWidth: Double
}

// MARK: - Premium Ring View

struct PremiumRingView: View {
    let data: RingData

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    private let accentColor = Color(red: 0.2, green: 0.8, blue: 0.4)

    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.8),
                        accentColor.opacity(0.4),
                        accentColor.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: data.strokeWidth
            )
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(data.delay)) {
                    opacity = 0.8
                    scale = 0.5
                }

                withAnimation(.easeOut(duration: data.duration).delay(data.delay + 0.1)) {
                    scale = data.maxScale
                }

                withAnimation(.easeIn(duration: 0.5).delay(data.delay + data.duration * 0.55)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Shimmer Particle Data

struct ShimmerParticle: Identifiable {
    let id: Int
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
}

// MARK: - Shimmer Particle View

struct ShimmerParticleView: View {
    let data: ShimmerParticle
    let center: CGPoint

    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0
    @State private var blur: CGFloat = 0

    private let accentColor = Color(red: 0.2, green: 0.8, blue: 0.4)

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white,
                        accentColor.opacity(0.8),
                        accentColor.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: data.size
                )
            )
            .frame(width: data.size * 2, height: data.size * 2)
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
            .offset(offset)
            .position(center)
            .onAppear {
                // Calculate target position
                let targetX = cos(data.angle) * data.distance
                let targetY = sin(data.angle) * data.distance

                // Start slightly inward
                let startX = cos(data.angle) * (data.distance * 0.3)
                let startY = sin(data.angle) * (data.distance * 0.3)
                offset = CGSize(width: startX, height: startY)

                // Fade in and scale up
                withAnimation(.easeOut(duration: 0.3).delay(data.delay)) {
                    opacity = 1
                    scale = 1
                }

                // Float outward
                withAnimation(.easeOut(duration: data.duration).delay(data.delay)) {
                    offset = CGSize(width: targetX, height: targetY)
                }

                // Gentle fade and blur out
                withAnimation(.easeIn(duration: 0.6).delay(data.delay + data.duration * 0.5)) {
                    opacity = 0
                    blur = 2
                    scale = 0.5
                }
            }
    }
}

// MARK: - Camera Picker View

struct CameraPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var capturedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.parent.capturedImage = image
                }
            } else {
                parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Scan Syncing Arrow View

struct ScanSyncingArrowView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let rotation = seconds.truncatingRemainder(dividingBy: 1.0) * 360

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(rotation))
        }
    }
}

// MARK: - Scale Scan Button Style

struct ScaleScanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ReceiptScanView()
        .environmentObject(TransactionManager())
        .environmentObject(AuthenticationManager())
}

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
    @ObservedObject private var processingManager = ReceiptProcessingManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var receiptsViewModel = ReceiptsViewModel()
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var errorMessage: String?
    @State private var errorTitle: String = L("upload_failed")
    @State private var showError = false
    @State private var uploadState: ReceiptUploadState = .idle
    @State private var uploadedReceipt: ReceiptUploadResponse?
    @State private var showReceiptDetails = false
    @State private var canRetryAfterError = false
    @State private var showRateLimitAlert = false
    @State private var showCaptureSuccess = false
    @State private var showProfile = false

    @Environment(\.selectedTabIndex) private var selectedTabIndex
    @State private var isTabVisible = false
    @State private var contentOpacity: Double = 0

    // Receipt detail sheet (tapped from RecentReceiptsCard)
    @State private var selectedReceipt: ReceiptUploadResponse?
    @State private var showRecentReceiptDetails = false

    // Recent receipts card
    @State private var isRecentReceiptsExpanded = false

    // Wallet Pass Creator
    @State private var showWalletPassCreator = false

    // Total receipts count (all time)
    @State private var totalReceiptsScanned: Int = 0

    // Total items scanned (all time)
    @State private var totalItemsScanned: Int = 0

    // Top stores stats (top 3)
    @State private var topStores: [(name: String, visits: Int)] = []

    // Top categories (all time) for flippable card
    @State private var topCategories: [TopCategory] = []
    @State private var isTopStoresCardFlipped = true

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
            isTabVisible = true
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
            // Reload any receipts persisted by the share extension
            processingManager.reloadPersistedReceipts()
            loadTotalReceiptsCount()
            loadAllTimeStats()
            Task {
                await receiptsViewModel.loadReceipts(period: "All", loadAll: false)
            }
        }
        .onDisappear {
            isTabVisible = false
            contentOpacity = 0
        }
        .onChange(of: selectedTabIndex) { _, newTab in
            if newTab != ContentView.Tab.home.rawValue && isRecentReceiptsExpanded {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRecentReceiptsExpanded = false
                }
            }
        }
        .receiptErrorOverlay(
            isPresented: $showError,
            title: errorTitle,
            message: errorMessage ?? "Failed to process receipt",
            onRetry: canRetryAfterError ? {
                errorMessage = nil
                errorTitle = L("upload_failed")
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
        } content: {
            if let receipt = uploadedReceipt {
                ReceiptDetailsView(receipt: receipt) {
                    // Receipt was deleted - notify to refresh data
                    NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                }
            }
        }
        .sheet(isPresented: $showRecentReceiptDetails) {
            if let receipt = selectedReceipt {
                ReceiptDetailsView(receipt: receipt) {
                    NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                    selectedReceipt = nil
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
        .sheet(isPresented: $showWalletPassCreator) {
            WalletPassCreatorView()
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
        .alert(L("upload_limit_reached"), isPresented: $showRateLimitAlert) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(rateLimitManager.receiptLimitMessage ?? L("upload_limit_month"))
        }
        .onAppear {
            // Sync rate limit when view appears to ensure we have latest count
            Task {
                await rateLimitManager.syncFromBackend()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
            // Refresh all stats and receipt list when a receipt is uploaded (from any source)
            loadAllTimeStats()
            Task {
                await receiptsViewModel.loadReceipts(period: "All", loadAll: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Pick up any receipts uploaded via the share extension while app was in background
            processingManager.reloadPersistedReceipts()
        }
        .animation(.easeInOut, value: uploadState)
    }

    // MARK: - Floating Scan Button

    // Premium glass card styling
    private var scanPremiumCardBackground: some View {
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

    private var scanPremiumCardBorder: some View {
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

    // Deep purple color matching overview tab theme
    private var deepPurple: Color {
        Color(red: 0.35, green: 0.10, blue: 0.60)
    }

    // Deep ocean blue header gradient color for scan tab
    private let headerBlueColor = Color(red: 0.04, green: 0.15, blue: 0.30)

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
                    Label("\(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit) \(L("receipt_plural"))", systemImage: receiptLimitIcon)
                }
                .tint(receiptLimitColor)
            }

            // Profile
            Section {
                Button {
                    showProfile = true
                } label: {
                    Label(L("profile"), systemImage: "person.fill")
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
                // Processing receipts card
                ProcessingReceiptsCard(manager: processingManager)
                    .padding(.horizontal, 20)

                // Recent receipts history (collapsible, lazy-loaded)
                RecentReceiptsCard(
                    viewModel: receiptsViewModel,
                    isExpanded: $isRecentReceiptsExpanded
                ) { receipt in
                    let response = receipt.toReceiptUploadResponse()
                    selectedReceipt = response
                    showRecentReceiptDetails = true
                }
                .padding(.horizontal, 20)

                // Stats Section
                statsSection
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                // Share tip card
                shareHintCard
                    .padding(.horizontal, 20)

                // Wallet Pass Creator card
                walletPassCard
                    .padding(.horizontal, 20)

                Spacer()
                    .frame(height: 120)
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
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
        )
        .opacity(contentOpacity)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 12) {
            // Top 3 Stores card
            topStoresCard
        }
    }

    // MARK: - Insight Strip

    /// Average items per receipt
    private var avgBasketSize: Double {
        guard totalReceiptsScanned > 0 else { return 0 }
        return Double(totalItemsScanned) / Double(totalReceiptsScanned)
    }

    private var insightStrip: some View {
        HStack(spacing: 8) {
            // Avg basket size
            insightPill(
                icon: "basket.fill",
                value: avgBasketSize > 0 ? String(format: "%.1f", avgBasketSize) : "—",
                label: "AVG BASKET",
                color: Color(red: 0.4, green: 0.7, blue: 1.0)
            )

            // Top store
            insightPill(
                icon: "storefront.fill",
                value: topStores.first?.name.localizedCapitalized ?? "—",
                label: "TOP STORE",
                color: Color.cyan
            )

            // Top category
            insightPill(
                icon: topCategories.first?.icon ?? "square.grid.2x2.fill",
                value: topCategories.first?.name.localizedCategoryName ?? "—",
                label: "#1 CATEGORY",
                color: topCategories.first?.name.normalizedCategoryName.categoryColor ?? Color.purple
            )
        }
    }

    private func insightPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Top Stores Card (Flippable)

    @State private var flipDegrees: Double = 180

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
        VStack(alignment: .leading, spacing: 0) {
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

                Text(L("top_stores"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Flip hint
                if !topCategories.isEmpty {
                    HStack(spacing: 4) {
                        Text(L("tap_for_categories"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Stores list
            if topStores.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "storefront")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.2))
                        Text(L("no_stores_yet"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topStores.enumerated()), id: \.offset) { index, store in
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                            topStoreRow(rank: index + 1, name: store.name, visits: store.visits)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(scanPremiumCardBackground)
        .overlay(scanPremiumCardBorder)
    }

    // Back side content - Top Categories
    private var topCategoriesCardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "cart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.purple)
                }

                Text(L("top_categories"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Flip hint
                HStack(spacing: 4) {
                    Text(L("tap_for_stores"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Categories list
            if topCategories.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "cart")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.2))
                        Text(L("no_categories_yet"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topCategories.prefix(3).enumerated()), id: \.offset) { index, category in
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                            topCategoryRow(rank: index + 1, category: category)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(scanPremiumCardBackground)
        .overlay(scanPremiumCardBorder)
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
            Image.categorySymbol(category.icon)
                .foregroundStyle(medalColor)
                .frame(width: 18, height: 18)

            // Category name
            Text(category.name.localizedCategoryName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Spent amount with label
            VStack(alignment: .trailing, spacing: 2) {
                Text("€\(category.totalSpent, specifier: "%.0f")")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(medalColor)
                Text(L("spent"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
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
                Text(L("visits"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
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

    // MARK: - Share Hint Card

    private var shareHintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.85, green: 0.2, blue: 0.6))

            VStack(alignment: .leading, spacing: 3) {
                Text(L("got_digital_receipt"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(L("use_share_button"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding()
        .background(scanPremiumCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(scanPremiumCardBorder)
    }

    // MARK: - Wallet Pass Card

    private var walletPassCard: some View {
        Button {
            showWalletPassCreator = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                // Wallet icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.black, Color.black.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("wallet_pass_creator"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(L("wallet_pass_desc"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(scanPremiumCardBackground)
            .overlay(scanPremiumCardBorder)
        }
        .buttonStyle(ScaleCardButtonStyle())
    }

    // MARK: - Syncing Status Banners

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

    // MARK: - Load Stats

    /// Load all-time stats from the new backend endpoint
    /// Falls back to the old multi-request approach if the new endpoint isn't available yet
    private func loadTotalReceiptsCount() {
        // Refresh all-time stats (total receipts, top stores, top categories)
        loadAllTimeStats()
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
            // Failed to load all-time stats
        }
    }

    // MARK: - Process Receipt

    private func processReceipt(image: UIImage) async {
        // Check image quality
        let qualityChecker = ReceiptQualityChecker()
        let qualityResult = await qualityChecker.checkQuality(of: image)

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

                errorTitle = L("quality_check_failed")
                errorMessage = message
                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            return
        }

        // Upload receipt
        await MainActor.run {
            uploadState = .uploading
        }

        do {
            let result = try await ReceiptUploadService.shared.uploadReceipt(image: image)

            await MainActor.run {
                capturedImage = nil

                switch result {
                case .accepted(let accepted):
                    // Async processing — hand off to processing manager
                    processingManager.addReceipt(accepted)
                    rateLimitManager.decrementReceiptLocal()
                    uploadState = .idle

                case .completed(let response):
                    // Legacy synchronous response
                    switch response.status {
                    case .success, .completed:
                        uploadState = .success(response)
                        uploadedReceipt = response

                        rateLimitManager.decrementReceiptLocal()
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
                        uploadState = .idle

                    case .failed:
                        uploadState = .failed("Receipt processing failed")
                        canRetryAfterError = true
                        errorMessage = "The receipt could not be processed. Please try again."
                        showError = true
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
        } catch let error as ReceiptUploadError {
            await MainActor.run {
                uploadState = .failed(error.localizedDescription)

                if case .rateLimitExceeded = error {
                    canRetryAfterError = false
                    errorMessage = error.rateLimitUserMessage ?? "Upload limit reached for this month."
                    Task {
                        await RateLimitManager.shared.syncFromBackend()
                    }
                } else {
                    canRetryAfterError = true
                    errorMessage = error.localizedDescription
                }

                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            await MainActor.run {
                uploadState = .failed(error.localizedDescription)
                canRetryAfterError = true
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
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
                Text(L("done"))
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

// MARK: - Scale Card Button Style

struct ScaleCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ReceiptScanView()
        .environmentObject(TransactionManager())
        .environmentObject(AuthenticationManager())
}

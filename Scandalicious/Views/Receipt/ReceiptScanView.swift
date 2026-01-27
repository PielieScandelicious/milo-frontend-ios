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

    // Total receipts count (all time)
    @State private var totalReceiptsScanned: Int = 0

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
        }
        .onDisappear {
            isTabVisible = false
        }
        .receiptErrorOverlay(
            isPresented: $showError,
            message: errorMessage ?? "Failed to process receipt",
            onRetry: canRetryAfterError ? {
                errorMessage = nil
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
                        try? await Task.sleep(for: .seconds(0.8))
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.2)) {
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
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)

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
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)

                // Usage indicator dot - shows reddest state
                Circle()
                    .fill(profileBadgeColor)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .offset(x: 2, y: 2)
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

                // Total Receipts Visualization Card
                totalReceiptsCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Recent Receipt Card (if exists)
                if let receipt = recentReceipt {
                    recentReceiptCard(receipt: receipt)
                        .padding(.horizontal, 20)
                }

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

    // MARK: - Total Receipts Card

    private var totalReceiptsCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Count
            VStack(spacing: 6) {
                Text("\(totalReceiptsScanned)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Total Receipts Scanned")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Remaining stat (centered)
            VStack(spacing: 4) {
                Text("\(rateLimitManager.receiptsRemaining)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(receiptLimitColor)
                Text("Remaining This Month")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Recent Receipt Card

    private func recentReceiptCard(receipt: ReceiptUploadResponse) -> some View {
        Button {
            showRecentReceiptDetails = true
        } label: {
            HStack(spacing: 14) {
                // Store icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "cart.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                }

                // Receipt info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Scan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)

                    Text(receipt.storeName ?? "Receipt")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        if let total = receipt.totalAmount {
                            Text(String(format: "€%.2f", total))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Text("\(receipt.itemsCount) items")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share Hint Card

    private var shareHintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.purple)

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

            Text("Syncing receipt...")
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
            Image(systemName: "checkmark.circle.fill")
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

    // MARK: - Load Total Receipts

    private func loadTotalReceiptsCount() {
        Task {
            do {
                // Get all-time receipts count by fetching with no date filter
                let response = try await AnalyticsAPIService.shared.fetchReceipts(filters: ReceiptFilters(page: 1, pageSize: 1))
                await MainActor.run {
                    totalReceiptsScanned = response.total
                }
            } catch {
                print("Failed to load total receipts count: \(error)")
            }
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

                var message = "Receipt quality too low.\n\n"
                if !qualityResult.issues.isEmpty {
                    for issue in qualityResult.issues {
                        message += "• \(issue.rawValue)\n"
                    }
                    message += "\n"
                }
                message += "Tips: Good lighting, hold steady, capture entire receipt"

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
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Success card
            VStack(spacing: 20) {
                // Animated checkmark circle
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Inner filled circle
                    Circle()
                        .fill(Color.green)
                        .frame(width: 70, height: 70)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)

                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                // Done text
                Text("Done!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(checkmarkOpacity)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
            .scaleEffect(checkmarkScale > 0 ? 1 : 0.8)
        }
        .onAppear {
            // Animate in sequence
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                ringScale = 1.2
                ringOpacity = 1.0
            }

            // Ring pulse out
            withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                ringScale = 1.4
                ringOpacity = 0
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

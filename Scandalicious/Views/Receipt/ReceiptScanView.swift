//
//  ReceiptScanView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

struct ReceiptScanView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @ObservedObject private var rateLimitManager = RateLimitManager.shared
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastCheckedUploadTimestamp: TimeInterval = 0

    // Syncing status for top banner
    @State private var isSyncing = false
    @State private var isTabVisible = false

    var body: some View {
        ZStack {
            scanPlaceholderView

            // Capture success overlay
            if showCaptureSuccess {
                CaptureSuccessOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            // Syncing status banner at top
            VStack {
                if isTabVisible && (isSyncing || rateLimitManager.isReceiptUploading) {
                    syncingStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if isTabVisible && rateLimitManager.showReceiptSynced {
                    syncedStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSyncing)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTabVisible)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.isReceiptUploading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.showReceiptSynced)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTabVisible = true
                }
            }
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
            uploadedReceipt = nil
        } content: {
            if let receipt = uploadedReceipt {
                ReceiptDetailsView(receipt: receipt) {
                    // Receipt was deleted - notify to refresh data
                    NotificationCenter.default.post(name: .receiptDeleted, object: nil)
                }
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
        .animation(.easeInOut, value: uploadState)
    }

    // MARK: - Scan Placeholder View

    private var scanPlaceholderView: some View {
        Button {
            // Check rate limit before showing camera
            if rateLimitManager.canUploadReceipt() {
                showCamera = true
            } else {
                showRateLimitAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } label: {
            VStack(spacing: 0) {
                Spacer()

                // Main camera button area
                VStack(spacing: 24) {
                    // Camera icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.4), radius: 24, y: 10)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white)
                    }

                    // Title and description
                    VStack(spacing: 10) {
                        Text("Snap Your Receipt")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Take a photo and we'll extract all items automatically")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 48)

                Spacer()

                // Upload limit indicator
                uploadLimitIndicator
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Bottom tip
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
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.05))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upload Limit Indicator

    private var uploadLimitIndicator: some View {
        let state = rateLimitManager.receiptLimitState
        let color: Color = {
            switch state {
            case .normal: return .green
            case .warning: return .orange
            case .exhausted: return .red
            }
        }()

        return HStack(spacing: 10) {
            Image(systemName: state == .exhausted ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(rateLimitManager.receiptUsageDisplayString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text(rateLimitManager.resetDaysFormatted)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if state == .exhausted {
                Text("Limit Reached")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Syncing Status Banners

    private var syncingStatusBanner: some View {
        HStack(spacing: 6) {
            SyncingArrowsView()
            Text("Syncing...")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.blue)
        .padding(.top, 12)
    }

    private var syncedStatusBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 11))
            Text("Synced")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.top, 12)
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

                    // Optimistically update rate limit counter
                    rateLimitManager.decrementReceiptLocal()

                    NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    showReceiptDetails = true

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

    /// Initialize the last checked timestamp to the current value in shared defaults
    private func initializeLastCheckedTimestamp() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let currentTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
            if lastCheckedUploadTimestamp == 0 && currentTimestamp > 0 {
                // Don't initialize to current value - we WANT to detect uploads that happened
                // while the app wasn't running. Only set to 0 to ensure we check.
                print("📋 [ScanTab] Found existing upload timestamp: \(currentTimestamp), will check for new uploads")
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

            // Update last checked timestamp
            lastCheckedUploadTimestamp = uploadTimestamp

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

#Preview {
    ReceiptScanView()
        .environmentObject(TransactionManager())
}

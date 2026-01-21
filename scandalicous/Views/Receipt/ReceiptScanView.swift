//
//  ReceiptScanView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI
import VisionKit
import Vision

struct ReceiptScanView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @State private var showDocumentScanner = false
    @State private var capturedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var uploadState: ReceiptUploadState = .idle
    @State private var uploadedReceipt: ReceiptUploadResponse?
    @State private var showReceiptDetails = false
    @State private var isCheckingQuality = false
    @State private var qualityCheckProgress: String = ""
    @State private var canRetryAfterError = false
    
    var body: some View {
        ZStack {
            placeholderView
            
            // Upload overlay
            if case .uploading = uploadState {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Processing receipt...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .transition(.scale.combined(with: .opacity))
            }
            
            // Processing overlay
            if case .processing = uploadState {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Processing receipt...")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Extracting items and prices")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .receiptErrorOverlay(
            isPresented: $showError,
            message: errorMessage ?? "Failed to process receipt",
            onRetry: canRetryAfterError ? {
                // Reset state and allow retry
                errorMessage = nil
                capturedImage = nil
                uploadState = .idle
                isCheckingQuality = false
                canRetryAfterError = false
                showDocumentScanner = true
            } : nil
        )
        .fullScreenCover(isPresented: $showDocumentScanner) {
            DocumentScannerView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showReceiptDetails) {
            // Clean up state when sheet is dismissed
            showReceiptDetails = false
            uploadedReceipt = nil
        } content: {
            if let receipt = uploadedReceipt {
                ReceiptDetailsView(receipt: receipt)
            }
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                Task {
                    await processReceipt(image: image)
                }
            }
        }
        .animation(.easeInOut, value: uploadState)
        .animation(.easeInOut, value: isCheckingQuality)
    }
    
    private var placeholderView: some View {
        Button {
            showDocumentScanner = true
        } label: {
            ScrollView {
                VStack(spacing: 28) {
                    // Quick Action Button - Prominent at top
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: .blue.opacity(0.4), radius: 20, y: 8)
                            
                            Image(systemName: "doc.viewfinder.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Scan Receipt")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionStep(
                            number: 1,
                            icon: "viewfinder",
                            iconColor: .blue,
                            title: "Tap to Scan",
                            description: "Tap anywhere on this screen to open the scanner"
                        )
                        
                        InstructionStep(
                            number: 2,
                            icon: "camera.fill",
                            iconColor: .green,
                            title: "Position Receipt",
                            description: "Hold your device steady over the receipt"
                        )
                        
                        InstructionStep(
                            number: 3,
                            icon: "checkmark.circle.fill",
                            iconColor: .orange,
                            title: "Quality Check",
                            description: "The app will automatically verify image quality before upload"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Digital Receipt Tip
                    InstructionStep(
                        number: 4,
                        icon: "square.and.arrow.up.fill",
                        iconColor: .purple,
                        title: "Digital Receipts",
                        description: "Use the Share button from any app to upload receipts directly."
                    )
                    .padding(.horizontal, 20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .buttonStyle(.plain)
    }
    
    private func processReceipt(image: UIImage) async {
        // Prevent multiple simultaneous processing
        guard uploadState == .idle, !isCheckingQuality else {
            print("Already processing, skipping")
            return
        }
        
        // Step 1: Check image quality using Apple Vision
        await MainActor.run {
            isCheckingQuality = true
            qualityCheckProgress = "Analyzing image quality..."
        }
        
        let qualityChecker = ReceiptQualityChecker()
        let qualityResult = await qualityChecker.checkQuality(of: image)
        
        print("📊 Quality Check Results:")
        print("   Acceptable: \(qualityResult.isAcceptable)")
        print("   Quality Score: \(String(format: "%.1f%%", qualityResult.qualityScore * 100))")
        print("   Text Blocks: \(qualityResult.detectedTextBlocks)")
        print("   Text Confidence: \(String(format: "%.1f%%", qualityResult.textConfidence * 100))")
        print("   Has Numbers: \(qualityResult.hasNumericContent)")
        print("   Issues: \(qualityResult.issues.map { $0.rawValue })")
        
        // Check if quality is acceptable
        guard qualityResult.isAcceptable else {
            await MainActor.run {
                isCheckingQuality = false
                capturedImage = nil
                canRetryAfterError = true // Allow retry for quality issues
                
                // Construct detailed error message
                var message = "Receipt quality too low for accurate processing.\n\n"
                
                if !qualityResult.issues.isEmpty {
                    message += "Issues detected:\n"
                    for issue in qualityResult.issues {
                        message += "• \(issue.rawValue)\n"
                    }
                    message += "\n"
                }
                
                message += "Quality Score: \(String(format: "%.1f%%", qualityResult.qualityScore * 100))\n"
                message += "Minimum Required: 60%\n\n"
                message += "Tips:\n"
                message += "• Ensure good lighting\n"
                message += "• Hold device steady\n"
                message += "• Capture entire receipt"
                
                errorMessage = message
                showError = true
                
                // Trigger error haptic
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            return
        }
        
        // Quality check passed!
        print("✅ Quality check PASSED! Score: \(String(format: "%.1f%%", qualityResult.qualityScore * 100))")
        if !qualityResult.issues.isEmpty {
            print("⚠️ Minor warnings (not blocking): \(qualityResult.issues.map { $0.rawValue })")
        }
        
        // Quality check passed - proceed with upload
        await MainActor.run {
            isCheckingQuality = false
            uploadState = .uploading
        }
        
        print("✅ Quality check passed! Uploading to server...")
        
        do {
            // Upload receipt to server (Claude Vision API)
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)
            print("✅ Receipt uploaded successfully - ID: \(response.receiptId)")
            
            await MainActor.run {
                capturedImage = nil
                
                // Check status
                switch response.status {
                case .success, .completed:
                    uploadState = .success(response)
                    uploadedReceipt = response
                    
                    print("🎉 Receipt processing successful!")
                    print("   Store: \(response.storeName ?? "N/A")")
                    print("   Total: €\(response.totalAmount ?? 0.0)")
                    print("   Items: \(response.transactions.count)")
                    
                    // ✅ Receipt is already uploaded to backend!
                    // Post notification to refresh View tab data
                    NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)
                    print("✅ Posted notification to refresh backend data")
                    
                    // Success haptic
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    
                    // Show details
                    showReceiptDetails = true
                    
                    // Reset after delay
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
                    
                case .failed:
                    uploadState = .failed("Receipt processing failed")
                    canRetryAfterError = true
                    errorMessage = "The receipt could not be processed by the server. Please try again."
                    showError = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        } catch let error as ReceiptUploadError {
            print("❌ Upload error: \(error.localizedDescription)")
            
            await MainActor.run {
                uploadState = .failed(error.localizedDescription)
                canRetryAfterError = true
                errorMessage = error.localizedDescription
                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            
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

// MARK: - Document Scanner View

struct DocumentScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var capturedImage: UIImage?
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        private var isProcessing = false
        
        init(parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Prevent duplicate processing
            guard !isProcessing else {
                print("⚠️ Already processing, ignoring duplicate call")
                return
            }
            isProcessing = true
            
            print("📸 Document scanner finished with \(scan.pageCount) page(s)")
            
            // Ensure at least one page was scanned
            guard scan.pageCount > 0 else {
                print("❌ No pages scanned")
                parent.dismiss()
                return
            }
            
            // Get the best single page (even if multiple pages were scanned)
            Task {
                let bestImage = await self.selectBestReceiptImage(from: scan)
                
                await MainActor.run {
                    print("✅ Best receipt selected, dismissing scanner")
                    self.parent.dismiss()
                    
                    // Set image after brief delay to ensure dismiss completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.parent.capturedImage = bestImage
                    }
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            print("📸 Document scanner cancelled")
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("❌ Document scanner failed: \(error.localizedDescription)")
            parent.dismiss()
        }
        
        // MARK: - Select Best Receipt
        
        /// Analyzes all scanned pages and returns the single best quality image
        private func selectBestReceiptImage(from scan: VNDocumentCameraScan) async -> UIImage {
            print("🔍 Analyzing \(scan.pageCount) page(s) to find best quality...")
            
            // If only one page, return it immediately
            if scan.pageCount == 1 {
                print("📄 Single page scan, using directly")
                return scan.imageOfPage(at: 0)
            }
            
            // Multiple pages - analyze quality of each
            let qualityChecker = ReceiptQualityChecker()
            var bestImage: UIImage = scan.imageOfPage(at: 0)
            var highestScore: Double = 0.0
            
            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                let result = await qualityChecker.checkQuality(of: image)
                
                print("📄 Page \(index + 1):")
                print("   Quality Score: \(String(format: "%.1f%%", result.qualityScore * 100))")
                print("   Text Blocks: \(result.detectedTextBlocks)")
                print("   Acceptable: \(result.isAcceptable)")
                
                if result.qualityScore > highestScore {
                    highestScore = result.qualityScore
                    bestImage = image
                }
            }
            
            print("✅ Best image: Score \(String(format: "%.1f%%", highestScore * 100))")
            return bestImage
        }
    }
}

// MARK: - Instruction Step Component

struct InstructionStep: View {
    let number: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ReceiptScanView()
        .environmentObject(TransactionManager())
}

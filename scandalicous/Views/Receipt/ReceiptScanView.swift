//
//  ReceiptScanView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

struct ReceiptScanView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var uploadState: ReceiptUploadState = .idle
    @State private var uploadedReceipt: ReceiptUploadResponse?
    @State private var showReceiptDetails = false
    @State private var canRetryAfterError = false

    var body: some View {
        ZStack {
            scanPlaceholderView

            // Processing overlay
            if case .uploading = uploadState {
                processingOverlay
            }

            if case .processing = uploadState {
                processingOverlay
            }
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
            CameraPickerView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showReceiptDetails) {
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
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
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

    // MARK: - Scan Placeholder View

    private var scanPlaceholderView: some View {
        Button {
            showCamera = true
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
                    VStack(spacing: 8) {
                        Text("Snap Your Receipt")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text("Take a photo and we'll extract all items automatically")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 48)

                Spacer()

                // Bottom tip
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Got a digital receipt?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Use the Share button from any app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .buttonStyle(.plain)
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
        }

        do {
            let response = try await ReceiptUploadService.shared.uploadReceipt(image: image)

            await MainActor.run {
                capturedImage = nil

                switch response.status {
                case .success, .completed:
                    uploadState = .success(response)
                    uploadedReceipt = response

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

                case .failed:
                    uploadState = .failed("Receipt processing failed")
                    canRetryAfterError = true
                    errorMessage = "The receipt could not be processed. Please try again."
                    showError = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        } catch let error as ReceiptUploadError {
            await MainActor.run {
                uploadState = .failed(error.localizedDescription)
                canRetryAfterError = true
                errorMessage = error.localizedDescription
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

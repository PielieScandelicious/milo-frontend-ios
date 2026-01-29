//
//  CustomCameraView.swift
//  Scandalicious
//
//  Redesigned seamless receipt capture experience
//  Single view for both single-shot and multi-section long receipts
//

import SwiftUI
import AVFoundation
import UIKit

enum CaptureMode: String, CaseIterable {
    case normal = "Normal"
    case longReceipt = "Long Receipt"
}

struct CustomCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var capturedImage: UIImage?

    @StateObject private var cameraService = CameraService()

    // Mode selection
    @State private var captureMode: CaptureMode = .normal

    // Animation states
    @State private var showCaptureFlash = false
    @State private var flyingImageData: FlyingImageData?
    @State private var flyingToIndex: Int?
    @State private var pendingAnimationImage: UIImage?
    @State private var pendingAnimationIndex: Int?
    @State private var pendingAnimationStartFrame: CGRect?
    @State private var thumbnailFrames: [Int: CGRect] = [:]

    // Review states
    @State private var showReviewSheet = false
    @State private var isProcessing = false
    @State private var previewImage: UIImage?

    private let cameraCoordinateSpace = "cameraView"

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Camera Preview - always active
                CameraPreviewRepresentable(session: cameraService.session)
                    .ignoresSafeArea()

                // Capture flash effect
                if showCaptureFlash {
                    Color.white
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // Main UI overlay
                VStack(spacing: 0) {
                    // Top bar with flash toggle
                    topBar

                    Spacer()

                    // Captured sections thumbnail strip (only in long receipt mode)
                    if captureMode == .longReceipt && !cameraService.allCapturedImages.isEmpty {
                        capturedSectionsStrip(geometry: geometry)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Bottom controls
                    bottomControls(geometry: geometry)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cameraService.allCapturedImages.count)

                // Flying image animation - positioned in same coordinate space as thumbnails
                if let flyingData = flyingImageData {
                    FlyingImageView(
                        image: flyingData.image,
                        startFrame: flyingData.startFrame,
                        endFrame: flyingData.endFrame,
                        screenSize: geometry.size,
                        onComplete: {
                            flyingImageData = nil
                            flyingToIndex = nil
                        }
                    )
                    .ignoresSafeArea()
                }

                // Processing overlay
                if isProcessing {
                    processingOverlay
                        .transition(.opacity)
                }
            }
            .coordinateSpace(name: cameraCoordinateSpace)
        }
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.15), value: showCaptureFlash)
        .fullScreenCover(isPresented: $showReviewSheet) {
            ReviewImageView(
                images: cameraService.allCapturedImages,
                previewImage: previewImage,
                onConfirm: finishCapture,
                onRetake: {
                    cameraService.reset()
                    previewImage = nil
                    showReviewSheet = false
                },
                onAddMore: {
                    showReviewSheet = false
                },
                showAddMore: captureMode == .longReceipt
            )
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Flash toggle button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                cameraService.toggleFlash()
            }) {
                Image(systemName: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(cameraService.isFlashOn ? .yellow : .white)
                    .frame(width: 40, height: 40)
                    .background(cameraService.isFlashOn ? Color.yellow.opacity(0.2) : Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    // MARK: - Captured Sections Strip

    @ViewBuilder
    private func thumbnailItem(index: Int, image: UIImage) -> some View {
        ThumbnailView(image: image, index: index + 1, isAnimatingIn: flyingToIndex == index)
            .id(index)
            .opacity(flyingToIndex == index ? 0 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let frame = geo.frame(in: .named(cameraCoordinateSpace))
                            thumbnailFrames[index] = frame
                            // Skip animation for first photo (index 0) - strip is still animating in
                            if index > 0 {
                                triggerPendingAnimation(for: index, with: frame)
                            }
                        }
                }
            )
    }

    private func capturedSectionsStrip(geometry: GeometryProxy) -> some View {
        HStack(spacing: 8) {
            // Thumbnail images
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(cameraService.allCapturedImages.enumerated()), id: \.offset) { index, image in
                            thumbnailItem(index: index, image: image)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
                }
                .onChange(of: cameraService.allCapturedImages.count) { newCount in
                    withAnimation {
                        proxy.scrollTo(newCount - 1, anchor: .trailing)
                    }
                }
            }
            .frame(height: 70)

            // Review/Done button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                preparePreviewAndShowReview()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Done")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(20)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
    }

    // MARK: - Bottom Controls

    private func bottomControls(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Shutter button
            Button(action: { capturePhoto(geometry: geometry) }) {
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 74, height: 74)

                    // Inner filled circle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)

                    // Plus icon if already has captures (only in long receipt mode)
                    if captureMode == .longReceipt && !cameraService.allCapturedImages.isEmpty {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black.opacity(0.3))
                    }
                }
            }
            .disabled(cameraService.isCaptureInProgress)
            .opacity(cameraService.isCaptureInProgress ? 0.6 : 1.0)

            // Mode selector - hide when in long receipt mode with captures
            if !(captureMode == .longReceipt && !cameraService.allCapturedImages.isEmpty) {
                modeSelector
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // Reset images when switching modes
                        if captureMode != mode {
                            cameraService.reset()
                        }
                        captureMode = mode
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: captureMode == mode ? .semibold : .regular))
                        .foregroundColor(captureMode == mode ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(captureMode == mode ? Color.white : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
        )
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 60, height: 80)
                            .offset(y: CGFloat(index) * -8)
                            .scaleEffect(1.0 - CGFloat(index) * 0.05)
                    }

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }

                Text("Preparing preview...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }

    // MARK: - Actions

    private func capturePhoto(geometry: GeometryProxy) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Show flash effect
        withAnimation(.easeIn(duration: 0.05)) {
            showCaptureFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.15)) {
                showCaptureFlash = false
            }
        }

        if captureMode == .normal {
            // Normal mode: capture and immediately show review
            cameraService.capturePhoto { capturedImg in
                guard let image = capturedImg else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.previewImage = image
                self.showReviewSheet = true
            }
        } else {
            // Long receipt mode: capture and add to thumbnail strip
            let viewSize = geometry.size
            let imageWidth: CGFloat = 120
            let imageHeight: CGFloat = 160
            let startFrame = CGRect(
                x: (viewSize.width - imageWidth) / 2,
                y: (viewSize.height - imageHeight) / 2 - 40,
                width: imageWidth,
                height: imageHeight
            )

            let targetIndex = cameraService.allCapturedImages.count

            cameraService.capturePhoto { capturedImg in
                guard let image = capturedImg else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)

                // Store pending animation data - animation will trigger when thumbnail frame is captured
                self.pendingAnimationImage = image
                self.pendingAnimationIndex = targetIndex
                self.pendingAnimationStartFrame = startFrame
            }
        }
    }

    private func triggerPendingAnimation(for index: Int, with frame: CGRect) {
        // Check if this is the thumbnail we're waiting to animate to
        guard let pendingIndex = pendingAnimationIndex,
              let pendingImage = pendingAnimationImage,
              let startFrame = pendingAnimationStartFrame,
              index == pendingIndex else {
            return
        }

        // Clear pending state
        pendingAnimationImage = nil
        pendingAnimationIndex = nil
        pendingAnimationStartFrame = nil

        // Track which thumbnail we're animating to (to hide it during animation)
        flyingToIndex = index

        // Start the flying animation to the actual thumbnail position
        flyingImageData = FlyingImageData(
            image: pendingImage,
            startFrame: startFrame,
            endFrame: frame
        )
    }

    private func preparePreviewAndShowReview() {
        guard !cameraService.allCapturedImages.isEmpty else { return }

        if cameraService.allCapturedImages.count == 1 {
            previewImage = cameraService.allCapturedImages[0]
            showReviewSheet = true
        } else {
            isProcessing = true
            DispatchQueue.global(qos: .userInitiated).async {
                let stacked = ImageStacker.stack(cameraService.allCapturedImages)
                DispatchQueue.main.async {
                    isProcessing = false
                    previewImage = stacked ?? cameraService.allCapturedImages[0]
                    showReviewSheet = true
                }
            }
        }
    }

    private func finishCapture() {
        guard let image = previewImage else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        capturedImage = image
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Flying Image Data

struct FlyingImageData: Equatable {
    let image: UIImage
    let startFrame: CGRect
    let endFrame: CGRect
    let id = UUID()

    static func == (lhs: FlyingImageData, rhs: FlyingImageData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Flying Image View

struct FlyingImageView: View {
    let image: UIImage
    let startFrame: CGRect
    let endFrame: CGRect
    let screenSize: CGSize
    let onComplete: () -> Void

    @State private var currentFrame: CGRect = .zero
    @State private var opacity: CGFloat = 1

    var body: some View {
        GeometryReader { _ in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: currentFrame.width, height: currentFrame.height)
                .clipped()
                .cornerRadius(8)
                .position(x: currentFrame.midX, y: currentFrame.midY)
                .opacity(opacity)
                .shadow(color: .black.opacity(0.4 * opacity), radius: 12, y: 6)
        }
        .onAppear {
            // Set initial frame
            currentFrame = startFrame

            // Animate to end position
            withAnimation(.easeOut(duration: 0.38)) {
                currentFrame = endFrame
            }

            // Fade out at the end
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.06)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Thumbnail View

struct ThumbnailView: View {
    let image: UIImage
    let index: Int
    var isAnimatingIn: Bool = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 66)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Review Image View

struct ReviewImageView: View {
    let images: [UIImage]
    let previewImage: UIImage?
    let onConfirm: () -> Void
    let onRetake: () -> Void
    let onAddMore: () -> Void
    var showAddMore: Bool = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image preview - scrollable for long receipts, fitted for normal
                if showAddMore {
                    // Long receipt mode: scrollable
                    ScrollView {
                        if let image = previewImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                                .padding(16)
                        }
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                } else {
                    // Normal mode: fit to view without scroll
                    VStack {
                        Spacer()
                        if let image = previewImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                                .padding(.horizontal, 20)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                }

                Spacer(minLength: 8)

                // Bottom actions
                VStack(spacing: 10) {
                    // Primary action - Upload
                    Button(action: onConfirm) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Upload Receipt")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(14)
                    }

                    // Secondary actions
                    HStack(spacing: 12) {
                        Button(action: onRetake) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Retake")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }

                        if showAddMore {
                            Button(action: onAddMore) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Add More")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
                .padding(.top, 12)
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: showAddMore ? onAddMore : onRetake) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewRepresentable: UIViewControllerRepresentable {
    let session: AVCaptureSession

    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let controller = CameraPreviewViewController()
        controller.session = session
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {}
}

class CameraPreviewViewController: UIViewController {
    var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let session = session else { return }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

#Preview {
    CustomCameraView(capturedImage: .constant(nil))
}

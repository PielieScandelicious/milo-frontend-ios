//
//  CustomCameraView.swift
//  Scandalicious
//
//  Custom camera view with shutter button, flash control, and scroll capture for long receipts
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreMotion
import Accelerate
import Combine

// MARK: - Camera Mode

enum CameraMode: Equatable {
    case standard
    case scrollCapture
}

// MARK: - Scroll Speed Indicator

enum ScrollSpeedIndicator {
    case tooFast
    case perfect
    case tooSlow
    case stationary

    var color: Color {
        switch self {
        case .tooFast: return .orange
        case .perfect: return .green
        case .tooSlow: return .yellow
        case .stationary: return .gray
        }
    }

    var message: String {
        switch self {
        case .tooFast: return "Slow down"
        case .perfect: return "Perfect speed"
        case .tooSlow: return "Move a bit faster"
        case .stationary: return "Start moving down"
        }
    }

    var icon: String {
        switch self {
        case .tooFast: return "tortoise.fill"
        case .perfect: return "checkmark.circle.fill"
        case .tooSlow: return "hare.fill"
        case .stationary: return "arrow.down.circle"
        }
    }
}

// MARK: - Capture Quality

enum CaptureQuality {
    case excellent
    case good
    case poor

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .poor: return .red
        }
    }
}

// MARK: - Flash Mode

enum CameraFlashMode: CaseIterable {
    case off, on, auto

    var icon: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        }
    }

    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }

    var label: String {
        switch self {
        case .off: return "Off"
        case .on: return "On"
        case .auto: return "Auto"
        }
    }
}

// MARK: - Custom Camera View

struct CustomCameraView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var capturedImage: UIImage?

    @StateObject private var cameraManager = CameraManager()
    @State private var flashMode: CameraFlashMode = .auto
    @State private var cameraMode: CameraMode = .standard
    @State private var isCapturing = false
    @State private var showFlashPicker = false
    @State private var shutterScale: CGFloat = 1.0

    // Scroll capture state
    @State private var scrollCaptureImages: [UIImage] = []
    @State private var isScrollCapturing = false
    @State private var scrollCaptureProgress: CGFloat = 0
    @State private var captureTimer: Timer?
    @State private var showScrollCaptureHint = true

    // Motion tracking for smooth scroll guidance
    @StateObject private var motionManager = CameraMotionManager()
    @State private var scrollSpeed: ScrollSpeedIndicator = .perfect
    @State private var captureQuality: CaptureQuality = .good

    // Photo preview confirmation state
    @State private var showPhotoPreview = false
    @State private var previewImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()

                // Overlay UI
                VStack(spacing: 0) {
                    // Top bar
                    topBar

                    Spacer()

                    // Mode indicator and scroll capture guide
                    if cameraMode == .scrollCapture {
                        scrollCaptureOverlay(geometry: geometry)
                    }

                    Spacer()

                    // Bottom controls
                    bottomControls(geometry: geometry)
                }

                // Capture flash effect
                if isCapturing {
                    Color.white
                        .ignoresSafeArea()
                        .opacity(0.3)
                        .transition(.opacity)
                }

                // Flash picker overlay
                if showFlashPicker {
                    flashPickerOverlay
                }

                // Photo preview overlay
                if showPhotoPreview, let image = previewImage {
                    photoPreviewOverlay(image: image)
                        .transition(.opacity)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            cameraManager.checkPermissionAndSetup()
        }
        .onDisappear {
            cameraManager.stopSession()
            captureTimer?.invalidate()
            motionManager.stopMonitoring()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Clean up scroll capture if running
                if isScrollCapturing {
                    captureTimer?.invalidate()
                    captureTimer = nil
                    motionManager.stopMonitoring()
                }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            // Flash button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showFlashPicker.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: flashMode.icon)
                        .font(.system(size: 16, weight: .semibold))

                    if flashMode != .off {
                        Text(flashMode.label)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(flashMode == .off ? .white.opacity(0.7) : .yellow)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Flash Picker Overlay

    private var flashPickerOverlay: some View {
        VStack {
            Spacer()
                .frame(height: 80)

            HStack(spacing: 12) {
                ForEach(CameraFlashMode.allCases, id: \.self) { mode in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            flashMode = mode
                            showFlashPicker = false
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 22, weight: .semibold))

                            Text(mode.label)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(flashMode == mode ? .yellow : .white)
                        .frame(width: 70, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(flashMode == mode ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                        )
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showFlashPicker = false
                    }
                }
        )
    }

    // MARK: - Photo Preview Overlay

    private func photoPreviewOverlay(image: UIImage) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top header
                Text("Review your photo")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Photo preview - scrollable for long receipts
                ScrollView(.vertical, showsIndicators: true) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom action buttons
                VStack(spacing: 12) {
                    Text("Is all the receipt text clear and readable?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        // Retake button
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showPhotoPreview = false
                                previewImage = nil
                                // Reset scroll capture state for fresh retake
                                scrollCaptureImages = []
                                if cameraMode == .scrollCapture {
                                    showScrollCaptureHint = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Retake")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.2))
                            )
                        }

                        // Use Photo button
                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            let imageToUse = image
                            withAnimation(.easeOut(duration: 0.2)) {
                                showPhotoPreview = false
                                previewImage = nil
                            }
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.capturedImage = imageToUse
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Use Photo")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color.black.ignoresSafeArea())
        }
    }

    // MARK: - Scroll Capture Overlay

    private func scrollCaptureOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            // Edge guides
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 3)

                Spacer()

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .cyan.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 3)
            }
            .padding(.horizontal, 40)
            .opacity(isScrollCapturing ? 1 : 0.3)
            .animation(.easeInOut(duration: 0.3), value: isScrollCapturing)

            VStack(spacing: 16) {
                if showScrollCaptureHint && !isScrollCapturing {
                    // Instructions card - scrollable for smaller screens
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .cyan.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)

                                Image(systemName: "arrow.down")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                                    .symbolEffect(.bounce.up.byLayer, options: .repeating.speed(0.5))
                            }

                            VStack(spacing: 6) {
                                Text("Long Receipt Mode")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text("Position at the top of receipt, then move phone slowly downward")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Tips - compact layout
                            HStack(spacing: 16) {
                                tipItem(icon: "hand.raised.fill", text: "Steady")
                                tipItem(icon: "light.max", text: "Good light")
                                tipItem(icon: "arrow.down", text: "Slow")
                            }
                        }
                        .padding(20)
                    }
                    .frame(maxHeight: min(geometry.size.height * 0.35, 280))
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .padding(.horizontal, 24)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
                }

                Spacer()

                if isScrollCapturing {
                    // Live capture feedback
                    VStack(spacing: 12) {
                        // Speed indicator
                        HStack(spacing: 10) {
                            Image(systemName: scrollSpeed.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(scrollSpeed.color)

                            Text(scrollSpeed.message)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(scrollSpeed.color)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(scrollSpeed.color.opacity(0.2))
                        .clipShape(Capsule())

                        // Capture counter and progress
                        HStack(spacing: 16) {
                            // Recording indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: .red, radius: 4)

                                Text("REC")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.red)
                            }

                            // Segment count
                            HStack(spacing: 4) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 14, weight: .semibold))

                                Text("\(scrollCaptureImages.count)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)

                            // Progress ring
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                    .frame(width: 30, height: 30)

                                Circle()
                                    .trim(from: 0, to: min(scrollCaptureProgress, 1.0))
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 30, height: 30)
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial.opacity(0.9))
                        .clipShape(Capsule())
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 60)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isScrollCapturing)
        .animation(.easeInOut(duration: 0.2), value: scrollSpeed)
    }

    private func tipItem(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.cyan)

            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Bottom Controls

    private func bottomControls(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            // Mode selector
            HStack(spacing: 0) {
                modeButton(mode: .standard, title: "Standard", icon: "camera.fill")
                modeButton(mode: .scrollCapture, title: "Long Receipt", icon: "rectangle.expand.vertical")
            }
            .padding(4)
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(Capsule())

            // Shutter area
            HStack(alignment: .center) {
                // Gallery button placeholder (for symmetry)
                Circle()
                    .fill(Color.clear)
                    .frame(width: 60, height: 60)

                Spacer()

                // Shutter button
                shutterButton

                Spacer()

                // Gallery/Preview of captured images (for scroll capture)
                if cameraMode == .scrollCapture && !scrollCaptureImages.isEmpty {
                    ZStack {
                        ForEach(Array(scrollCaptureImages.suffix(3).enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                                .offset(x: CGFloat(index) * 4, y: CGFloat(index) * -4)
                        }

                        // Count badge
                        Text("\(scrollCaptureImages.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .offset(x: 25, y: -25)
                    }
                    .frame(width: 60, height: 60)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 60, height: 60)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
        }
        .padding(.top, 16)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Mode Button

    private func modeButton(mode: CameraMode, title: String, icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if cameraMode != mode {
                    // Stop any ongoing scroll capture before switching modes
                    if isScrollCapturing {
                        captureTimer?.invalidate()
                        captureTimer = nil
                        motionManager.stopMonitoring()
                        isScrollCapturing = false
                    }
                    cameraMode = mode
                    scrollCaptureImages = []
                    showScrollCaptureHint = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(cameraMode == mode ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(cameraMode == mode ? Color.white.opacity(0.25) : Color.clear)
            )
        }
    }

    // MARK: - Shutter Button

    private var shutterButton: some View {
        Button {
            handleShutterPress()
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Inner fill
                Circle()
                    .fill(
                        cameraMode == .scrollCapture && isScrollCapturing
                            ? Color.red
                            : Color.white
                    )
                    .frame(width: 66, height: 66)
                    .overlay {
                        if cameraMode == .scrollCapture && isScrollCapturing {
                            // Stop icon when recording
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        }
                    }

                // Pulse animation ring for scroll capture
                if cameraMode == .scrollCapture && isScrollCapturing {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(shutterScale)
                        .opacity(2 - shutterScale)
                }
            }
            .scaleEffect(isCapturing ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isCapturing)
        }
        .onAppear {
            // Pulse animation
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                shutterScale = 1.3
            }
        }
    }

    // MARK: - Actions

    private func handleShutterPress() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        switch cameraMode {
        case .standard:
            captureStandardPhoto()

        case .scrollCapture:
            if isScrollCapturing {
                stopScrollCapture()
            } else {
                startScrollCapture()
            }
        }
    }

    private func captureStandardPhoto() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isCapturing = true
        }

        cameraManager.capturePhoto(flashMode: flashMode.avFlashMode) { image in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.isCapturing = false
                }

                if let image = image {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Show preview for user confirmation
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.previewImage = image
                        self.showPhotoPreview = true
                    }
                }
            }
        }
    }

    private func startScrollCapture() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isScrollCapturing = true
            showScrollCaptureHint = false
            scrollCaptureImages = []
            scrollCaptureProgress = 0
        }

        // Start motion monitoring
        motionManager.startMonitoring()

        // Capture initial frame
        captureScrollFrame()

        // Start timer for continuous capture and motion updates
        // Use Timer with explicit RunLoop.main to ensure it fires properly
        let timer = Timer(timeInterval: 0.5, repeats: true) { [motionManager, cameraManager] _ in
            // Update speed indicator on main thread
            DispatchQueue.main.async {
                self.scrollSpeed = motionManager.getSpeedIndicator()
            }

            // Only capture if phone is relatively stable (not shaking) and not already capturing
            if motionManager.isStable && !cameraManager.isCapturing {
                self.captureScrollFrame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        captureTimer = timer
    }

    private func captureScrollFrame() {
        // Don't capture if already capturing
        guard !cameraManager.isCapturing else { return }

        cameraManager.capturePhoto(flashMode: flashMode == .off ? .off : .auto) { image in
            DispatchQueue.main.async {
                if let image = image {
                    self.scrollCaptureImages.append(image)

                    // Update progress (assuming max ~20 segments for a very long receipt)
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.scrollCaptureProgress = CGFloat(self.scrollCaptureImages.count) / 20.0
                    }

                    // Light haptic for each capture
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    private func stopScrollCapture() {
        captureTimer?.invalidate()
        captureTimer = nil

        // Stop motion monitoring
        motionManager.stopMonitoring()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isScrollCapturing = false
        }

        // Stitch images together
        if scrollCaptureImages.count >= 2 {
            // Show processing feedback
            UINotificationFeedbackGenerator().notificationOccurred(.warning)

            // Capture images locally before async task
            let imagesToStitch = scrollCaptureImages

            Task {
                if let stitchedImage = await stitchImages(imagesToStitch) {
                    await MainActor.run {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        // Show preview for user confirmation
                        withAnimation(.easeIn(duration: 0.2)) {
                            self.previewImage = stitchedImage
                            self.showPhotoPreview = true
                        }
                    }
                } else {
                    // Stitching failed, use first image as fallback
                    await MainActor.run {
                        if let fallbackImage = imagesToStitch.first {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            // Show preview for user confirmation
                            withAnimation(.easeIn(duration: 0.2)) {
                                self.previewImage = fallbackImage
                                self.showPhotoPreview = true
                            }
                        }
                    }
                }
            }
        } else if let singleImage = scrollCaptureImages.first {
            // Only one image captured, show preview for confirmation
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeIn(duration: 0.2)) {
                self.previewImage = singleImage
                self.showPhotoPreview = true
            }
        } else {
            // No images captured, just reset state
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showScrollCaptureHint = true
            }
        }
    }

    // MARK: - Image Stitching

    private func stitchImages(_ images: [UIImage]) async -> UIImage? {
        guard !images.isEmpty else { return nil }
        guard images.count >= 2 else { return images.first }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Configuration
                let overlapRatio: CGFloat = 0.38 // 38% overlap between consecutive captures
                let firstImage = images[0]
                let width = firstImage.size.width
                let singleHeight = firstImage.size.height
                let effectiveHeight = singleHeight * (1 - overlapRatio)
                let blendZoneHeight = singleHeight * overlapRatio

                // Calculate total canvas height
                let totalHeight = singleHeight + (CGFloat(images.count - 1) * effectiveHeight)

                // Create high-quality renderer
                let format = UIGraphicsImageRendererFormat()
                format.scale = firstImage.scale
                format.opaque = true

                let renderer = UIGraphicsImageRenderer(
                    size: CGSize(width: width, height: totalHeight),
                    format: format
                )

                let stitchedImage = renderer.image { ctx in
                    let context = ctx.cgContext

                    // Fill background
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))

                    var yOffset: CGFloat = 0

                    for (index, image) in images.enumerated() {
                        let imageRect = CGRect(x: 0, y: yOffset, width: width, height: singleHeight)

                        if index == 0 {
                            // First image: draw completely
                            image.draw(in: imageRect)
                        } else {
                            // For subsequent images: use gradient blending in overlap zone

                            // 1. Draw the non-overlapping portion (below blend zone)
                            let nonOverlapY = yOffset + blendZoneHeight
                            let nonOverlapHeight = singleHeight - blendZoneHeight

                            if nonOverlapHeight > 0 {
                                context.saveGState()
                                context.clip(to: CGRect(x: 0, y: nonOverlapY, width: width, height: nonOverlapHeight))
                                image.draw(in: imageRect)
                                context.restoreGState()
                            }

                            // 2. Draw the blend zone with alpha gradient
                            // We'll draw horizontal strips with increasing alpha
                            let strips = Int(blendZoneHeight / 2) // One strip per 2 points
                            for strip in 0..<strips {
                                let stripY = yOffset + CGFloat(strip) * 2
                                let alpha = CGFloat(strip) / CGFloat(strips)

                                context.saveGState()
                                context.setAlpha(alpha)
                                context.clip(to: CGRect(x: 0, y: stripY, width: width, height: 2))
                                image.draw(in: imageRect)
                                context.restoreGState()
                            }
                        }

                        yOffset += effectiveHeight
                    }
                }

                continuation.resume(returning: stitchedImage)
            }
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            if let session = session {
                previewLayer.session = session
            }
        }
    }

    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var error: String?
    @Published var isCapturing = false

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?

    // Use a dictionary to track multiple concurrent captures
    private var captureCompletions: [Int64: (UIImage?) -> Void] = [:]
    private var captureIdCounter: Int64 = 0
    private let captureQueue = DispatchQueue(label: "com.scandalicious.captureQueue")

    func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.error = "Camera access denied"
                    }
                }
            }
        default:
            error = "Camera access denied"
        }
    }

    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add video input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            error = "No camera available"
            return
        }

        currentDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            self.error = error.localizedDescription
            return
        }

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            // Use maximum available photo dimensions for best quality
            if let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
                $0.width * $0.height < $1.width * $1.height
            }) {
                photoOutput.maxPhotoDimensions = maxDimensions
            }
        }

        session.commitConfiguration()

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isAuthorized = true
            }
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func capturePhoto(flashMode: AVCaptureDevice.FlashMode, completion: @escaping (UIImage?) -> Void) {
        // Prevent concurrent captures from overwhelming the system
        guard !isCapturing else {
            completion(nil)
            return
        }

        captureQueue.sync {
            isCapturing = true
            captureIdCounter += 1
            let captureId = captureIdCounter
            captureCompletions[captureId] = completion
        }

        let settings = AVCapturePhotoSettings()

        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleTorch(on: Bool) {
        guard let device = currentDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to toggle torch: \(error)")
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            DispatchQueue.main.async {
                self.isCapturing = false
            }
        }

        // Get the completion handler for this capture
        let completion: ((UIImage?) -> Void)? = captureQueue.sync {
            // Get the oldest completion (FIFO)
            if let firstKey = captureCompletions.keys.sorted().first {
                return captureCompletions.removeValue(forKey: firstKey)
            }
            return nil
        }

        if let error = error {
            print("Photo capture error: \(error)")
            completion?(nil)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }

        // Fix orientation
        let fixedImage = fixOrientation(image)
        completion?(fixedImage)
    }

    private func fixOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }
}

// MARK: - Motion Manager

class CameraMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var verticalVelocity: Double = 0
    @Published var isMovingDown: Bool = false
    @Published var isStable: Bool = true

    private var lastAcceleration: CMAcceleration?
    private var velocityHistory: [Double] = []

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = 0.05 // 20Hz

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }

            // Track vertical movement (y-axis in portrait mode)
            let currentVelocity = acceleration.y

            // Add to history for smoothing
            self.velocityHistory.append(currentVelocity)
            if self.velocityHistory.count > 10 {
                self.velocityHistory.removeFirst()
            }

            // Calculate smoothed velocity
            let smoothedVelocity = self.velocityHistory.reduce(0, +) / Double(self.velocityHistory.count)

            DispatchQueue.main.async {
                self.verticalVelocity = smoothedVelocity
                self.isMovingDown = smoothedVelocity > 0.05 // Positive = moving down
                self.isStable = abs(acceleration.x) < 0.15 && abs(acceleration.z) < 0.15
            }

            self.lastAcceleration = acceleration
        }
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        velocityHistory.removeAll()
    }

    func getSpeedIndicator() -> ScrollSpeedIndicator {
        let absVelocity = abs(verticalVelocity)

        if absVelocity < 0.02 {
            return .stationary
        } else if absVelocity < 0.08 {
            return .tooSlow
        } else if absVelocity > 0.3 {
            return .tooFast
        } else {
            return .perfect
        }
    }
}

// MARK: - Preview

#Preview {
    CustomCameraView(capturedImage: .constant(nil))
}

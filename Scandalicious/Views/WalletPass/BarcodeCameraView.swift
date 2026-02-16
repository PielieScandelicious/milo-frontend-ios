//
//  BarcodeCameraView.swift
//  Scandalicious
//
//  Camera view for capturing barcodes and QR codes
//

import SwiftUI
import AVFoundation

struct BarcodeCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = LiveBarcodeScanner()
    @State private var capturedImage: UIImage?
    @State private var showingCapturedImage = false
    @State private var flashOn = false
    @State private var hasDetectedBarcode = false
    @State private var session: AVCaptureSession?

    let onImageCaptured: (UIImage) -> Void
    var onBarcodeDetected: ((DetectedBarcode) -> Void)? = nil

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: session)
                .ignoresSafeArea()

            // Scanning overlay
            scanningOverlay

            // Top controls
            VStack {
                topControls

                Spacer()

                // Bottom controls
                bottomControls
            }

            // Detection feedback
            if let barcode = scanner.detectedBarcode, !hasDetectedBarcode {
                detectionFeedback(barcode)
            }
        }
        .onAppear {
            // Setup session only once
            if session == nil {
                session = scanner.setupSession()
            }
            scanner.startScanning()
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .onChange(of: scanner.detectedBarcode) { _, newValue in
            if newValue != nil && !hasDetectedBarcode {
                captureCurrentFrame()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Scanning Overlay

    private var scanningOverlay: some View {
        GeometryReader { geo in
            let scanAreaSize = min(geo.size.width * 0.75, 280)
            let scanAreaY = (geo.size.height - scanAreaSize) / 2 - 60 // Move scan area up

            ZStack {
                // Darkened background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Scan area cutout - positioned higher
                Rectangle()
                    .fill(.clear)
                    .frame(width: scanAreaSize, height: scanAreaSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.15, blue: 0.70), Color(red: 0.6, green: 0.3, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .overlay(
                        // Corner accents
                        ZStack {
                            CornerAccent()
                                .position(x: 15, y: 15)

                            CornerAccent()
                                .rotationEffect(.degrees(90))
                                .position(x: scanAreaSize - 15, y: 15)

                            CornerAccent()
                                .rotationEffect(.degrees(270))
                                .position(x: 15, y: scanAreaSize - 15)

                            CornerAccent()
                                .rotationEffect(.degrees(180))
                                .position(x: scanAreaSize - 15, y: scanAreaSize - 15)
                        }
                        .frame(width: scanAreaSize, height: scanAreaSize)
                    )
                    .position(x: geo.size.width / 2, y: scanAreaY + scanAreaSize / 2)
                    .compositingGroup()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)

                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            // Flash toggle
            Button {
                toggleFlash()
            } label: {
                ZStack {
                    Circle()
                        .fill(flashOn ? Color.yellow : Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: flashOn ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(flashOn ? .black : .white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Instructions
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 18))
                    Text(L("position_barcode_within_frame"))
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.9))

                Text(L("qr_barcodes_loyalty_cards"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 8)

            // Manual capture button
            Button {
                captureCurrentFrame()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                }
            }

            Text(L("tap_to_capture_or_autodetect"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.bottom, 40)
    }

    // MARK: - Detection Feedback

    private func detectionFeedback(_ barcode: DetectedBarcode) -> some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)

                        Text(L("barcode_detected"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(barcode.value.prefix(40) + (barcode.value.count > 40 ? "..." : ""))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)

                    Text(barcode.type.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(20)
            }
            .frame(maxWidth: 300)
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3), value: barcode.id)
    }

    // MARK: - Helper Methods

    private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = flashOn ? .off : .on
            flashOn.toggle()
            device.unlockForConfiguration()
        } catch {
            // Flash toggle failed
        }
    }

    private func captureCurrentFrame() {
        hasDetectedBarcode = true

        // If we have a detected barcode, pass it directly
        if let barcode = scanner.detectedBarcode {
            // Use the direct barcode callback if available
            if let callback = onBarcodeDetected {
                callback(barcode)
                dismiss()
            } else {
                // Fallback: create a simple image (for backwards compatibility)
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))

                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center

                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .regular),
                        .paragraphStyle: paragraphStyle,
                        .foregroundColor: UIColor.black
                    ]

                    let string = barcode.value
                    string.draw(with: CGRect(x: 20, y: 180, width: 360, height: 40),
                              options: .usesLineFragmentOrigin,
                              attributes: attrs,
                              context: nil)
                }

                onImageCaptured(image)
                dismiss()
            }
        }
    }
}

// MARK: - Corner Accent

struct CornerAccent: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        if let session = session {
            view.setSession(session)
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if let session = session {
            uiView.setSession(session)
        }
    }
}

class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func setSession(_ session: AVCaptureSession) {
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}

// MARK: - Preview

#Preview {
    BarcodeCameraView { _ in }
}

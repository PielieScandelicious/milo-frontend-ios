//
//  ReceiptScanView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI
import AVFoundation
import Combine

struct ReceiptScanView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @State private var showCameraSheet = false
    @State private var capturedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccessMessage = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            placeholderView
            
            // Success message overlay
            if showSuccessMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Receipt saved successfully")
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showCameraSheet) {
            CameraSheet(capturedImage: $capturedImage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                errorMessage = nil
                capturedImage = nil
            }
        } message: {
            Text(errorMessage ?? "Failed to save receipt")
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                processReceipt(image: image)
            }
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("Ready to Scan")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the button below to scan a receipt")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showCameraSheet = true
            } label: {
                Label("Open Camera", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
    }
    
    private func processReceipt(image: UIImage) {
        Task {
            do {
                // Save image to receipts directory
                let savedURL = try saveReceiptImage(image)
                print("Receipt saved to: \(savedURL.path)")
                
                await MainActor.run {
                    capturedImage = nil
                    
                    // Show success message
                    withAnimation {
                        showSuccessMessage = true
                    }
                    
                    // Hide success message after 2 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation {
                            showSuccessMessage = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save receipt: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func saveReceiptImage(_ image: UIImage) throws -> URL {
        // Get documents directory
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ReceiptError.directoryNotFound
        }
        
        // Create receipts directory if it doesn't exist
        let receiptsDirectory = documentsDirectory.appendingPathComponent("receipts", isDirectory: true)
        
        if !fileManager.fileExists(atPath: receiptsDirectory.path) {
            try fileManager.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
        }
        
        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "receipt_\(timestamp).jpg"
        
        let fileURL = receiptsDirectory.appendingPathComponent(filename)
        
        // Convert image to JPEG data and save
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw ReceiptError.imageConversionFailed
        }
        
        try imageData.write(to: fileURL)
        
        return fileURL
    }
}

// MARK: - Errors

enum ReceiptError: LocalizedError {
    case directoryNotFound
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "Could not find documents directory"
        case .imageConversionFailed:
            return "Failed to convert image to JPEG format"
        }
    }
}

// MARK: - Camera Sheet

struct CameraSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var capturedImage: UIImage?
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            if cameraManager.isSimulator {
                simulatorPlaceholder
            } else {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            }
            
            // Camera controls overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                HStack(spacing: 60) {
                    // Flash toggle
                    Button {
                        cameraManager.toggleFlash()
                    } label: {
                        Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(cameraManager.isSimulator)
                    .opacity(cameraManager.isSimulator ? 0.5 : 1)
                    
                    // Capture button
                    Button {
                        cameraManager.capturePhoto()
                    } label: {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 75, height: 75)
                            .overlay {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 65, height: 65)
                            }
                    }
                    .disabled(cameraManager.isSimulator)
                    .opacity(cameraManager.isSimulator ? 0.5 : 1)
                    
                    // Flip camera
                    Button {
                        cameraManager.flipCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(cameraManager.isSimulator)
                    .opacity(cameraManager.isSimulator ? 0.5 : 1)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.capturedPhoto) { _, photo in
            if let photo {
                capturedImage = photo
                cameraManager.capturedPhoto = nil // Reset for next time
                dismiss()
            }
        }
    }
    
    private var simulatorPlaceholder: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Camera Not Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("Camera preview is only available on physical devices")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // No updates needed
    }
    
    class CameraPreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var capturedPhoto: UIImage?
    @Published var isFlashOn = false
    
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.dobby.camera")
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    override init() {
        super.init()
    }
    
    func startSession() {
        guard !isSimulator else { return }
        
        checkPermissions { [weak self] authorized in
            guard authorized, let self = self else { return }
            self.setupCamera()
        }
    }
    
    func stopSession() {
        guard !isSimulator else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    private func checkPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Setup camera input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoDeviceInput = input
            }
            
            // Setup photo output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    func capturePhoto() {
        guard !isSimulator else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.isFlashOn ? .on : .off
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func flipCamera() {
        guard !isSimulator else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let currentInput = self.videoDeviceInput else { return }
            
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else { return }
            
            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDeviceInput = newInput
            } else {
                // Revert if failed
                self.session.addInput(currentInput)
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        Task { @MainActor in
            self.capturedPhoto = image
        }
    }
}

#Preview {
    ReceiptScanView()
        .environmentObject(TransactionManager())
}

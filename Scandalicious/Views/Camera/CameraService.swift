import AVFoundation
import SwiftUI
import Combine
import UIKit

class CameraService: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var recentImage: UIImage? // The "Ghost" image
    @Published var allCapturedImages: [UIImage] = []
    @Published var isFlashOn = false
    @Published var isCaptureInProgress = false

    private let photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private var captureCompletion: ((UIImage?) -> Void)?

    override init() {
        super.init()
        checkPermissions()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { self.setupCamera() } }
            }
        default: break
        }
    }

    private func setupCamera() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        self.captureDevice = device

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        session.commitConfiguration()

        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }

    func toggleFlash() {
        guard let device = captureDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .on {
                device.torchMode = .off
                DispatchQueue.main.async { self.isFlashOn = false }
            } else {
                try device.setTorchModeOn(level: 1.0)
                DispatchQueue.main.async { self.isFlashOn = true }
            }

            device.unlockForConfiguration()
        } catch {
            // Flash toggle error
        }
    }

    func capturePhoto(completion: ((UIImage?) -> Void)? = nil) {
        guard !isCaptureInProgress else { return }

        DispatchQueue.main.async {
            self.isCaptureInProgress = true
        }

        self.captureCompletion = completion

        let settings = AVCapturePhotoSettings()
        if let device = captureDevice, device.hasTorch && isFlashOn {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func reset() {
        allCapturedImages.removeAll()
        recentImage = nil
    }

    func removeImage(at index: Int) {
        guard index >= 0 && index < allCapturedImages.count else { return }
        allCapturedImages.remove(at: index)
        if allCapturedImages.isEmpty {
            recentImage = nil
        } else {
            recentImage = allCapturedImages.last
        }
    }

    func moveImage(from: Int, to: Int) {
        guard from >= 0 && from < allCapturedImages.count,
              to >= 0 && to < allCapturedImages.count else { return }
        let image = allCapturedImages.remove(at: from)
        allCapturedImages.insert(image, at: to)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            DispatchQueue.main.async {
                self.isCaptureInProgress = false
            }
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.captureCompletion?(nil)
                self.captureCompletion = nil
            }
            return
        }

        // Correct orientation immediately
        let fixedImage = fixOrientation(img: image)

        DispatchQueue.main.async {
            self.allCapturedImages.append(fixedImage)
            self.recentImage = fixedImage // Update the "Ghost"
            self.captureCompletion?(fixedImage)
            self.captureCompletion = nil
        }
    }

    // Helper to normalize image orientation (vital for Vision)
    private func fixOrientation(img: UIImage) -> UIImage {
        if img.imageOrientation == .up { return img }
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        img.draw(in: CGRect(origin: .zero, size: img.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? img
    }
}
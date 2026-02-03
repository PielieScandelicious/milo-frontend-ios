//
//  BarcodeScanner.swift
//  Scandalicious
//
//  Service for detecting barcodes and QR codes from images
//

import Foundation
import UIKit
import Vision
import AVFoundation
import Combine
import SwiftUI

actor BarcodeScanner {
    static let shared = BarcodeScanner()

    private init() {}

    // MARK: - Detect Barcodes from Image

    func detectBarcodes(in image: UIImage) async throws -> [DetectedBarcode] {
        guard let cgImage = image.cgImage else {
            throw BarcodeScannerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let barcodes = results.compactMap { observation -> DetectedBarcode? in
                    guard let payloadString = observation.payloadStringValue else { return nil }

                    let barcodeType = self.mapSymbologyToWalletType(observation.symbology)
                    let bounds = observation.boundingBox

                    return DetectedBarcode(
                        value: payloadString,
                        type: barcodeType,
                        bounds: bounds
                    )
                }

                continuation.resume(returning: barcodes)
            }

            // Configure for all barcode types
            request.symbologies = [
                .qr,
                .pdf417,
                .aztec,
                .code128,
                .code39,
                .code93,
                .ean8,
                .ean13,
                .upce,
                .itf14,
                .dataMatrix,
                .codabar,
                .gs1DataBar,
                .gs1DataBarExpanded,
                .gs1DataBarLimited
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Map Vision Symbology to Wallet Type

    private func mapSymbologyToWalletType(_ symbology: VNBarcodeSymbology) -> WalletBarcodeType {
        switch symbology {
        case .qr:
            return .qr
        case .pdf417:
            return .pdf417
        case .aztec:
            return .aztec
        case .code128, .code39, .code93, .ean8, .ean13, .upce, .itf14, .codabar:
            return .code128
        default:
            return .qr
        }
    }

    // MARK: - Get Best Barcode

    func getBestBarcode(from image: UIImage) async throws -> DetectedBarcode? {
        let barcodes = try await detectBarcodes(in: image)

        // Prefer QR codes, then larger barcodes
        let sorted = barcodes.sorted { b1, b2 in
            // QR codes first
            if b1.type == .qr && b2.type != .qr { return true }
            if b2.type == .qr && b1.type != .qr { return false }

            // Then by size
            let size1 = b1.bounds.width * b1.bounds.height
            let size2 = b2.bounds.width * b2.bounds.height
            return size1 > size2
        }

        return sorted.first
    }

    // MARK: - Enhance Image for Detection

    func enhanceImageForDetection(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let context = CIContext()

        // Apply contrast enhancement
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return image }
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.1, forKey: kCIInputContrastKey)
        contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Grayscale

        guard let contrastOutput = contrastFilter.outputImage else { return image }

        // Apply sharpening
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        sharpenFilter.setValue(contrastOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputSharpnessKey)

        guard let finalOutput = sharpenFilter.outputImage,
              let cgImage = context.createCGImage(finalOutput, from: finalOutput.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Live Camera Scanner

class LiveBarcodeScanner: NSObject, ObservableObject {
    @Published var detectedBarcode: DetectedBarcode?
    @Published var isScanning = false

    private var captureSession: AVCaptureSession?
    private let metadataOutput = AVCaptureMetadataOutput()

    override init() {
        super.init()
    }

    func setupSession() -> AVCaptureSession? {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return nil
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [
                .qr, .pdf417, .aztec, .code128, .code39, .code93,
                .ean8, .ean13, .upce, .itf14, .dataMatrix
            ]
        }

        captureSession = session
        return session
    }

    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isScanning = true
            }
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
        isScanning = false
    }
}

extension LiveBarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        let barcodeType = mapMetadataType(metadataObject.type)

        DispatchQueue.main.async { [weak self] in
            self?.detectedBarcode = DetectedBarcode(
                value: stringValue,
                type: barcodeType,
                bounds: metadataObject.bounds
            )

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func mapMetadataType(_ type: AVMetadataObject.ObjectType) -> WalletBarcodeType {
        switch type {
        case .qr:
            return .qr
        case .pdf417:
            return .pdf417
        case .aztec:
            return .aztec
        default:
            return .code128
        }
    }
}

// MARK: - Errors

enum BarcodeScannerError: LocalizedError {
    case invalidImage
    case noBarcodeFound
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .noBarcodeFound:
            return "No barcode or QR code found in the image"
        case .cameraUnavailable:
            return "Camera is not available"
        }
    }
}

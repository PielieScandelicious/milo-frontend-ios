//
//  WalletPassViewModel.swift
//  Scandalicious
//
//  ViewModel for Wallet Pass Creator
//

import Foundation
import SwiftUI
import PassKit
import PhotosUI
import Combine
import FirebaseAuth

@MainActor
class WalletPassViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var passData = LoyaltyPassData()
    @Published var creationState: PassCreationState = .idle
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var showingLogoPicker = false
    @Published var imagePickerType: ImagePickerType = .barcode
    @Published var detectedBarcodes: [DetectedBarcode] = []
    @Published var isDetectingBarcode = false
    @Published var showingBarcodeOptions = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var passDataForWallet: Data?
    @Published var showingAddToWallet = false

    // MARK: - Computed Properties

    var canCreatePass: Bool {
        passData.isValid
    }

    var canAddToWallet: Bool {
        WalletPassService.shared.canAddPasses()
    }

    // MARK: - Image Picker Type

    enum ImagePickerType {
        case barcode
        case logo
    }

    // MARK: - Actions

    func selectBarcodeFromPhotos() {
        imagePickerType = .barcode
        showingImagePicker = true
    }

    func captureBarcode() {
        imagePickerType = .barcode
        showingCamera = true
    }

    func selectLogo() {
        imagePickerType = .logo
        showingLogoPicker = true
    }

    func processSelectedImage(_ image: UIImage) async {
        switch imagePickerType {
        case .barcode:
            await detectBarcodeFromImage(image)
        case .logo:
            setLogoImage(image)
        }
    }

    func setLogoImage(_ image: UIImage) {
        // Resize logo to reasonable size
        let maxSize: CGFloat = 200
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)

        if ratio < 1 {
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            passData.logoImage = resized
        } else {
            passData.logoImage = image
        }
    }

    func detectBarcodeFromImage(_ image: UIImage) async {
        isDetectingBarcode = true
        detectedBarcodes = []

        do {
            // Enhance image first
            let enhanced = await BarcodeScanner.shared.enhanceImageForDetection(image)

            // Detect barcodes
            let barcodes = try await BarcodeScanner.shared.detectBarcodes(in: enhanced)

            if barcodes.isEmpty {
                // Try with original image
                let originalBarcodes = try await BarcodeScanner.shared.detectBarcodes(in: image)
                detectedBarcodes = originalBarcodes
            } else {
                detectedBarcodes = barcodes
            }

            if detectedBarcodes.isEmpty {
                showError("No barcode or QR code found in the image. Please try another image or enter the code manually.")
            } else if detectedBarcodes.count == 1 {
                // Auto-select single barcode
                selectBarcode(detectedBarcodes[0])
            } else {
                // Show options for multiple barcodes
                showingBarcodeOptions = true
            }
        } catch {
            showError("Failed to scan barcode: \(error.localizedDescription)")
        }

        isDetectingBarcode = false
    }

    func selectBarcode(_ barcode: DetectedBarcode) {
        passData.barcodeValue = barcode.value
        passData.barcodeType = barcode.type

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func selectColorPreset(_ preset: PassColorPreset) {
        passData.colorPreset = preset

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func createAndAddPass() async {
        guard canCreatePass else {
            showError("Please fill in all required fields")
            return
        }

        guard canAddToWallet else {
            showError("This device cannot add passes to Apple Wallet")
            return
        }

        creationState = .creatingPass

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        do {
            // Get auth token
            guard let token = try await Auth.auth().currentUser?.getIDToken() else {
                throw WalletPassError.signingFailed("Not authenticated")
            }

            // Convert colors to components (must happen on MainActor)
            let bgColor = passData.colorPreset.backgroundColor.rgbComponents
            let fgColor = passData.colorPreset.foregroundColor.rgbComponents
            let labelColor = passData.colorPreset.labelColor.rgbComponents

            // Convert logo to base64 if available
            var logoBase64: String? = nil
            if let logo = passData.logoImage, let pngData = logo.pngData() {
                logoBase64 = pngData.base64EncodedString()
            }

            // Build request
            let request = WalletPassCreateRequest(
                storeName: passData.storeName,
                memberNumber: passData.memberNumber,
                barcodeValue: passData.barcodeValue,
                barcodeFormat: passData.barcodeType.rawValue,
                backgroundColor: ColorComponents(red: bgColor.red, green: bgColor.green, blue: bgColor.blue),
                foregroundColor: ColorComponents(red: fgColor.red, green: fgColor.green, blue: fgColor.blue),
                labelColor: ColorComponents(red: labelColor.red, green: labelColor.green, blue: labelColor.blue),
                logoBase64: logoBase64
            )

            // Create pass via backend
            let passBytes = try await WalletPassService.shared.createPass(request: request, authToken: token)

            // Store pass data for Add to Wallet
            passDataForWallet = passBytes

            // Show Add to Wallet sheet
            showingAddToWallet = true

            // Update state
            creationState = .passReady(URL(fileURLWithPath: ""))

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

        } catch {
            creationState = .error(error.localizedDescription)
            showError(error.localizedDescription)
        }
    }

    func resetCreator() {
        passData = LoyaltyPassData()
        creationState = .idle
        detectedBarcodes = []
        errorMessage = nil
        passDataForWallet = nil
    }

    // MARK: - Helper Methods

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true

        // Reset state
        creationState = .idle

        // Error haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Add to Wallet View

struct AddToWalletView: UIViewControllerRepresentable {
    let passData: Data
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        do {
            let pass = try PKPass(data: passData)
            let controller = PKAddPassesViewController(pass: pass)!
            controller.delegate = context.coordinator
            return controller
        } catch {
            // Return empty controller that will be dismissed
            let controller = PKAddPassesViewController(passes: [])!
            return controller
        }
    }

    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            onDismiss()
        }
    }
}

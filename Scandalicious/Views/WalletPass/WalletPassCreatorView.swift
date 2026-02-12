//
//  WalletPassCreatorView.swift
//  Scandalicious
//
//  Premium Wallet Pass Creator for loyalty cards
//

import SwiftUI
import PhotosUI
import PassKit

struct WalletPassCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WalletPassViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var showingPassPreview = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient

                ScrollView {
                    VStack(spacing: 24) {
                        // Store Details Section
                        storeDetailsSection

                        // Barcode Section
                        barcodeSection

                        // Color Selection
                        colorSelectionSection

                        // Logo Section
                        logoSection

                        // Create Button
                        createPassButton

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.canCreatePass {
                        Button("Preview") {
                            showingPassPreview = true
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showingCamera) {
            BarcodeCameraView(
                onImageCaptured: { image in
                    Task {
                        await viewModel.processSelectedImage(image)
                    }
                },
                onBarcodeDetected: { barcode in
                    viewModel.selectBarcode(barcode)
                }
            )
        }
        .photosPicker(isPresented: $viewModel.showingImagePicker,
                     selection: $selectedPhotoItem,
                     matching: .images)
        .photosPicker(isPresented: $viewModel.showingLogoPicker,
                     selection: $selectedLogoItem,
                     matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            handlePhotoSelection(newValue, isLogo: false)
        }
        .onChange(of: selectedLogoItem) { _, newValue in
            handlePhotoSelection(newValue, isLogo: true)
        }
        .confirmationDialog("Multiple Barcodes Found",
                           isPresented: $viewModel.showingBarcodeOptions,
                           titleVisibility: .visible) {
            ForEach(viewModel.detectedBarcodes) { barcode in
                Button(barcode.value.prefix(30) + (barcode.value.count > 30 ? "..." : "")) {
                    viewModel.selectBarcode(barcode)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select the barcode you want to use")
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .sheet(isPresented: $showingPassPreview) {
            PassPreviewSheet(passData: viewModel.passData)
        }
        .sheet(isPresented: $viewModel.showingAddToWallet) {
            if let passData = viewModel.passDataForWallet {
                AddToWalletView(passData: passData) {
                    viewModel.showingAddToWallet = false
                    viewModel.resetCreator()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.05, green: 0.05, blue: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Pass Preview Card

    private var passPreviewCard: some View {
        VStack(spacing: 0) {
            // Mini pass preview
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewModel.passData.colorPreset.backgroundColor)
                    .frame(height: 180)

                VStack(spacing: 12) {
                    // Header with logo and title
                    HStack(spacing: 12) {
                        if let logo = viewModel.passData.logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "building.2")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                        }

                        Text(viewModel.passData.storeName.isEmpty ? "Store Name" : viewModel.passData.storeName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(viewModel.passData.colorPreset.foregroundColor)

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Barcode area (visual only)
                    if !viewModel.passData.barcodeValue.isEmpty {
                        ZStack {
                            // White background for barcode
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white)
                                .frame(height: 55)
                                .padding(.horizontal, 16)

                            // Barcode visualization
                            BarcodeVisualizer(
                                value: viewModel.passData.barcodeValue,
                                type: viewModel.passData.barcodeType,
                                foregroundColor: .black
                            )
                            .frame(height: 40)
                            .padding(.horizontal, 28)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 32))
                                .foregroundStyle(viewModel.passData.colorPreset.foregroundColor.opacity(0.3))

                            Text("Scan barcode below")
                                .font(.system(size: 12))
                                .foregroundStyle(viewModel.passData.colorPreset.labelColor.opacity(0.5))
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
    }

    // MARK: - Store Details Section

    private var storeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Store Details", icon: "building.2.fill")

            VStack(spacing: 12) {
                // Store name field
                PremiumTextField(
                    icon: "storefront",
                    placeholder: "Store Name",
                    text: $viewModel.passData.storeName
                )
            }
        }
    }

    // MARK: - Barcode Section

    private var barcodeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Loyalty Card Barcode", icon: "barcode.viewfinder")

            VStack(spacing: 12) {
                // Barcode visualization when detected
                if !viewModel.passData.barcodeValue.isEmpty {
                    VStack(spacing: 0) {
                        // Barcode visual display
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .frame(height: 120)

                            VStack(spacing: 8) {
                                // Barcode visualization
                                BarcodeVisualizer(
                                    value: viewModel.passData.barcodeValue,
                                    type: viewModel.passData.barcodeType,
                                    foregroundColor: .black
                                )
                                .frame(height: 70)
                                .padding(.horizontal, 24)
                            }
                        }

                        // Success indicator and clear button
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.green)

                                Text("Barcode captured")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            Spacer()

                            Button {
                                viewModel.passData.barcodeValue = ""
                                viewModel.passData.barcodeType = .qr
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Rescan")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding(.top, 12)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    // Scan buttons when no barcode
                    HStack(spacing: 12) {
                        BarcodeActionButton(
                            icon: "camera.fill",
                            title: "Scan",
                            subtitle: "Take photo"
                        ) {
                            viewModel.captureBarcode()
                        }

                        BarcodeActionButton(
                            icon: "photo.on.rectangle",
                            title: "Upload",
                            subtitle: "From photos"
                        ) {
                            viewModel.selectBarcodeFromPhotos()
                        }
                    }

                    // Manual entry option (collapsed by default)
                    DisclosureGroup {
                        PremiumTextField(
                            icon: "number",
                            placeholder: "Enter barcode value",
                            text: $viewModel.passData.barcodeValue
                        )
                        .padding(.top, 8)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 12))
                            Text("Enter manually")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .tint(.white.opacity(0.5))
                }
            }

            // Loading indicator
            if viewModel.isDetectingBarcode {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Detecting barcode...")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    // MARK: - Color Selection Section

    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Pass Color", icon: "paintpalette.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PassColorPreset.presets) { preset in
                        ColorPresetButton(
                            preset: preset,
                            isSelected: viewModel.passData.colorPreset == preset
                        ) {
                            viewModel.selectColorPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Store Logo", icon: "photo.fill")

            Button {
                viewModel.selectLogo()
            } label: {
                HStack(spacing: 16) {
                    if let logo = viewModel.passData.logoImage {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.08))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.passData.logoImage != nil ? "Change Logo" : "Add Logo")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Optional - appears on pass header")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Create Pass Button

    private var createPassButton: some View {
        VStack(spacing: 12) {
            if viewModel.creationState == .creatingPass {
                // Loading state
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Creating Pass...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                // Official Apple Wallet button
                AddToWalletButton {
                    Task {
                        await viewModel.createAndAddPass()
                    }
                }
                .frame(height: 56)
                .opacity(viewModel.canCreatePass ? 1.0 : 0.4)
                .disabled(!viewModel.canCreatePass)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    // MARK: - Photo Selection Handler

    private func handlePhotoSelection(_ item: PhotosPickerItem?, isLogo: Bool) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                if isLogo {
                    viewModel.setLogoImage(image)
                } else {
                    await viewModel.processSelectedImage(image)
                }
            }
        }

        // Clear selection
        if isLogo {
            selectedLogoItem = nil
        } else {
            selectedPhotoItem = nil
        }
    }
}

// MARK: - Premium Text Field

struct PremiumTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .tint(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Barcode Action Button

struct BarcodeActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.45, green: 0.15, blue: 0.70), Color(red: 0.35, green: 0.10, blue: 0.60)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Barcode Type Chip

struct BarcodeTypeChip: View {
    let type: WalletBarcodeType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 12))

                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(red: 0.35, green: 0.10, blue: 0.60) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(red: 0.45, green: 0.15, blue: 0.70) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Color Preset Button

struct ColorPresetButton: View {
    let preset: PassColorPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(preset.backgroundColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: preset.backgroundColor.opacity(0.5), radius: isSelected ? 8 : 0)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(preset.foregroundColor)
                    }
                }

                Text(preset.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Pass Preview Sheet

struct PassPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let passData: LoyaltyPassData

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Full pass preview
                    PassCardView(passData: passData)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)

                    // Info text
                    VStack(spacing: 8) {
                        Text("Pass Preview")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("This is how your loyalty card will appear in Apple Wallet")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Pass Card View

struct PassCardView: View {
    let passData: LoyaltyPassData

    var body: some View {
        VStack(spacing: 0) {
            // Pass content
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    if let logo = passData.logoImage {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text(passData.storeName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(passData.colorPreset.foregroundColor)

                    Spacer()
                }

                Spacer()

                // Barcode (visual only, no text)
                ZStack {
                    // White background for barcode readability
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(height: 90)

                    BarcodeVisualizer(
                        value: passData.barcodeValue,
                        type: passData.barcodeType,
                        foregroundColor: .black
                    )
                    .frame(height: 70)
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 8)
            }
            .padding(20)
            .background(passData.colorPreset.backgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
    }
}

// MARK: - Barcode Visualizer

struct BarcodeVisualizer: View {
    let value: String
    let type: WalletBarcodeType
    let foregroundColor: Color

    var body: some View {
        Group {
            switch type {
            case .qr:
                // Simple QR pattern
                qrPattern
            default:
                // Barcode pattern
                barcodePattern
            }
        }
    }

    private var qrPattern: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            Canvas { context, _ in
                let moduleSize = size / 25
                let hash = value.hashValue

                for row in 0..<25 {
                    for col in 0..<25 {
                        // Position detection patterns (corners)
                        let isCornerPattern = isInPositionPattern(row: row, col: col, size: 25)

                        // Generate deterministic pattern from value
                        let shouldFill = isCornerPattern || ((hash >> ((row * 25 + col) % 64)) & 1) == 1

                        if shouldFill {
                            let rect = CGRect(
                                x: CGFloat(col) * moduleSize,
                                y: CGFloat(row) * moduleSize,
                                width: moduleSize,
                                height: moduleSize
                            )
                            context.fill(Path(rect), with: .color(foregroundColor))
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
    }

    private func isInPositionPattern(row: Int, col: Int, size: Int) -> Bool {
        // Top-left
        if row < 7 && col < 7 {
            if row == 0 || row == 6 || col == 0 || col == 6 { return true }
            if row >= 2 && row <= 4 && col >= 2 && col <= 4 { return true }
        }
        // Top-right
        if row < 7 && col >= size - 7 {
            let adjustedCol = col - (size - 7)
            if row == 0 || row == 6 || adjustedCol == 0 || adjustedCol == 6 { return true }
            if row >= 2 && row <= 4 && adjustedCol >= 2 && adjustedCol <= 4 { return true }
        }
        // Bottom-left
        if row >= size - 7 && col < 7 {
            let adjustedRow = row - (size - 7)
            if adjustedRow == 0 || adjustedRow == 6 || col == 0 || col == 6 { return true }
            if adjustedRow >= 2 && adjustedRow <= 4 && col >= 2 && col <= 4 { return true }
        }
        return false
    }

    private var barcodePattern: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let barCount = 50
                let hash = value.hashValue
                var x: CGFloat = 0

                for i in 0..<barCount {
                    let width = CGFloat(2 + (hash >> (i % 32)) % 3)
                    let shouldDraw = ((hash >> (i % 64)) & 1) == 1

                    if shouldDraw {
                        let rect = CGRect(x: x, y: 0, width: width, height: size.height)
                        context.fill(Path(rect), with: .color(foregroundColor))
                    }

                    x += width + 2
                    if x > size.width { break }
                }
            }
        }
    }
}

// MARK: - Pass Success View

struct PassSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let passData: LoyaltyPassData
    let onDone: () -> Void

    @State private var showCheckmark = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Success checkmark
                if showCheckmark {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Title
                if showContent {
                    VStack(spacing: 12) {
                        Text("Pass Created!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Your \(passData.storeName) loyalty card is ready")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Pass preview
                if showContent {
                    PassCardView(passData: passData)
                        .frame(maxWidth: 280)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer()

                // Info card
                if showContent {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Coming Soon")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)

                                Text("Direct Apple Wallet integration is being set up. For now, you can save or screenshot your pass.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Done button
                if showContent {
                    Button {
                        onDone()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.15, blue: 0.70), Color(red: 0.35, green: 0.10, blue: 0.60)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            // Animate in sequence
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showCheckmark = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showContent = true
                }
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Add to Wallet Button (Official Apple Button)

struct AddToWalletButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PillShapedPassButtonContainer {
        let container = PillShapedPassButtonContainer()
        container.button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return container
    }

    func updateUIView(_ uiView: PillShapedPassButtonContainer, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func buttonTapped() {
            action()
        }
    }
}

// Custom container that applies pill shape
class PillShapedPassButtonContainer: UIView {
    let button = PKAddPassButton(addPassButtonStyle: .black)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

// MARK: - Preview

#Preview {
    WalletPassCreatorView()
}

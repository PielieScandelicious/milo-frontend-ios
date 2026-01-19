//
//  ReceiptScanView.swift
//  Dobby
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
    @State private var showSuccessMessage = false
    
    var body: some View {
        ZStack {
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
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                errorMessage = nil
                capturedImage = nil
            }
        } message: {
            Text(errorMessage ?? "Failed to save receipt")
        }
        .fullScreenCover(isPresented: $showDocumentScanner) {
            DocumentScannerView(capturedImage: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                processReceipt(image: image)
            }
        }
    }
    
    private var placeholderView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Quick Action Button - Prominent at top
                Button {
                    showDocumentScanner = true
                } label: {
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
                            
                            HStack(spacing: 4) {
                                Text("Tap to scan")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 32)
                
                // Steps
                VStack(alignment: .leading, spacing: 16) {
                    InstructionStep(
                        number: 1,
                        icon: "viewfinder",
                        iconColor: .blue,
                        title: "Tap Scan Receipt",
                        description: "Tap the button above to open the scanner"
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
                        title: "Scan & Review",
                        description: "Capture one or more scans - the app will automatically select the best one"
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
        
        init(parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Get all scanned pages and select the best one
            guard scan.pageCount > 0 else {
                parent.dismiss()
                return
            }
            
            // If only one page, use it
            if scan.pageCount == 1 {
                let image = scan.imageOfPage(at: 0)
                parent.capturedImage = image
                parent.dismiss()
                return
            }
            
            // Multiple pages - find the best one
            Task {
                let bestImage = await self.selectBestReceiptImage(from: scan)
                await MainActor.run {
                    self.parent.capturedImage = bestImage
                    self.parent.dismiss()
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner failed: \(error.localizedDescription)")
            parent.dismiss()
        }
        
        // MARK: - Image Quality Analysis
        
        private func selectBestReceiptImage(from scan: VNDocumentCameraScan) async -> UIImage {
            var imageScores: [(image: UIImage, score: Double)] = []
            
            // Analyze each scanned page
            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                let score = await analyzeImageQuality(image)
                imageScores.append((image: image, score: score))
                print("Page \(index): Quality score = \(score)")
            }
            
            // Return the image with the highest score
            let bestImage = imageScores.max(by: { $0.score < $1.score })?.image
            return bestImage ?? scan.imageOfPage(at: 0)
        }
        
        private func analyzeImageQuality(_ image: UIImage) async -> Double {
            guard let cgImage = image.cgImage else { return 0.0 }
            
            var totalScore: Double = 0.0
            
            // 1. Text Recognition Quality (most important for receipts)
            let textScore = await analyzeTextRecognition(cgImage)
            totalScore += textScore * 0.5  // 50% weight
            
            // 2. Image Sharpness/Focus
            let sharpnessScore = analyzeSharpness(cgImage)
            totalScore += sharpnessScore * 0.3  // 30% weight
            
            // 3. Contrast and Brightness
            let contrastScore = analyzeContrast(cgImage)
            totalScore += contrastScore * 0.2  // 20% weight
            
            return totalScore
        }
        
        private func analyzeTextRecognition(_ cgImage: CGImage) async -> Double {
            return await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: 0.0)
                        return
                    }
                    
                    // Calculate score based on:
                    // - Number of recognized text blocks
                    // - Average confidence of recognized text
                    // - Presence of numeric characters (important for receipts)
                    
                    var textCount = 0
                    var totalConfidence = 0.0
                    var hasNumbers = false
                    
                    for observation in observations {
                        guard let topCandidate = observation.topCandidates(1).first else { continue }
                        
                        textCount += 1
                        totalConfidence += Double(topCandidate.confidence)
                        
                        // Check for numbers (prices, totals, etc.)
                        if topCandidate.string.rangeOfCharacter(from: .decimalDigits) != nil {
                            hasNumbers = true
                        }
                    }
                    
                    let avgConfidence = textCount > 0 ? totalConfidence / Double(textCount) : 0.0
                    let textCountScore = min(Double(textCount) / 50.0, 1.0)  // Normalize to max 50 text blocks
                    let numberBonus = hasNumbers ? 0.2 : 0.0
                    
                    let score = (avgConfidence * 0.5) + (textCountScore * 0.3) + numberBonus
                    continuation.resume(returning: score)
                }
                
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }
        }
        
        private func analyzeSharpness(_ cgImage: CGImage) -> Double {
            // Use a simplified Laplacian variance method for blur detection
            // Higher variance = sharper image
            
            guard let dataProvider = cgImage.dataProvider,
                  let data = dataProvider.data,
                  let bytes = CFDataGetBytePtr(data) else {
                return 0.5  // Default middle score
            }
            
            let width = cgImage.width
            let height = cgImage.height
            let bytesPerRow = cgImage.bytesPerRow
            let bytesPerPixel = cgImage.bitsPerPixel / 8
            
            // Sample a grid of points (for performance)
            let sampleSize = min(width, height, 100)
            let stepX = max(width / sampleSize, 1)
            let stepY = max(height / sampleSize, 1)
            
            var variance: Double = 0.0
            var count = 0
            
            for y in stride(from: stepY, to: height - stepY, by: stepY) {
                for x in stride(from: stepX, to: width - stepX, by: stepX) {
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    let centerValue = Double(bytes[offset])
                    
                    // Calculate Laplacian (simplified)
                    let topOffset = (y - stepY) * bytesPerRow + x * bytesPerPixel
                    let bottomOffset = (y + stepY) * bytesPerRow + x * bytesPerPixel
                    let leftOffset = y * bytesPerRow + (x - stepX) * bytesPerPixel
                    let rightOffset = y * bytesPerRow + (x + stepX) * bytesPerPixel
                    
                    let laplacian = abs(4 * centerValue
                        - Double(bytes[topOffset])
                        - Double(bytes[bottomOffset])
                        - Double(bytes[leftOffset])
                        - Double(bytes[rightOffset]))
                    
                    variance += laplacian
                    count += 1
                }
            }
            
            let avgVariance = count > 0 ? variance / Double(count) : 0.0
            // Normalize to 0-1 range (values typically range from 0-100)
            return min(avgVariance / 100.0, 1.0)
        }
        
        private func analyzeContrast(_ cgImage: CGImage) -> Double {
            guard let dataProvider = cgImage.dataProvider,
                  let data = dataProvider.data,
                  let bytes = CFDataGetBytePtr(data) else {
                return 0.5
            }
            
            let width = cgImage.width
            let height = cgImage.height
            let bytesPerRow = cgImage.bytesPerRow
            let bytesPerPixel = cgImage.bitsPerPixel / 8
            
            // Sample pixels to calculate brightness distribution
            var brightnessValues: [Double] = []
            let sampleSize = min(width * height / 1000, 1000)  // Sample ~1000 pixels
            let step = max((width * height) / sampleSize, 1)
            
            for i in stride(from: 0, to: width * height, by: step) {
                let y = i / width
                let x = i % width
                
                guard y < height else { break }
                
                let offset = y * bytesPerRow + x * bytesPerPixel
                let brightness = Double(bytes[offset])
                brightnessValues.append(brightness)
            }
            
            // Calculate standard deviation (higher = better contrast)
            guard !brightnessValues.isEmpty else { return 0.5 }
            
            let mean = brightnessValues.reduce(0.0, +) / Double(brightnessValues.count)
            let variance = brightnessValues.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(brightnessValues.count)
            let stdDev = sqrt(variance)
            
            // Normalize (typical std dev range is 0-70 for good contrast)
            return min(stdDev / 70.0, 1.0)
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
            // Number badge
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(iconColor)
                    
                    Text("\(number)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor.opacity(0.7))
                }
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

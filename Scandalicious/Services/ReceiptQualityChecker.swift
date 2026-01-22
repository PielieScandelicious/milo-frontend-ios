//
//  ReceiptQualityChecker.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import UIKit
import Vision
import CoreImage

/// Quality check result for a scanned receipt
struct ReceiptQualityResult {
    let isAcceptable: Bool
    let qualityScore: Double // 0.0 to 1.0
    let issues: [QualityIssue]
    let textConfidence: Double
    let detectedTextBlocks: Int
    let hasNumericContent: Bool
    
    enum QualityIssue: String {
        case tooBlurry = "Image is too blurry. Hold your device steady."
        case poorLighting = "Poor lighting detected. Ensure good lighting conditions."
        case lowContrast = "Low contrast. Avoid shadows and ensure even lighting."
        case insufficientText = "Not enough text detected. Ensure the entire receipt is visible."
        case noNumbers = "No prices or numbers detected. Make sure amounts are visible."
        case lowResolution = "Image resolution too low. Move closer to the receipt."
        case poorTextQuality = "Text is not clear enough. Ensure text is sharp and readable."
    }
}

/// Service for checking receipt image quality using Apple Vision framework
actor ReceiptQualityChecker {
    
    // MARK: - Quality Thresholds
    
    private let minimumQualityScore: Double = 0.60  // Minimum overall score (60%)
    private let minimumTextBlocks: Int = 5          // At least 5 readable text blocks
    private let minimumTextConfidence: Double = 0.5  // 50% average confidence
    private let minimumSharpness: Double = 0.35      // Sharpness threshold
    private let minimumContrast: Double = 0.25       // Contrast threshold
    private let minimumResolution: CGFloat = 600     // Minimum width/height in pixels
    
    // MARK: - Quality Check
    
    /// Performs comprehensive quality check on a receipt image
    func checkQuality(of image: UIImage) async -> ReceiptQualityResult {
        guard let cgImage = image.cgImage else {
            return ReceiptQualityResult(
                isAcceptable: false,
                qualityScore: 0.0,
                issues: [.lowResolution],
                textConfidence: 0.0,
                detectedTextBlocks: 0,
                hasNumericContent: false
            )
        }
        
        var warnings: [ReceiptQualityResult.QualityIssue] = []
        var criticalIssues: [ReceiptQualityResult.QualityIssue] = []
        var scores: [Double] = []
        
        // 1. Check resolution
        let resolution = min(CGFloat(cgImage.width), CGFloat(cgImage.height))
        if resolution < minimumResolution {
            criticalIssues.append(.lowResolution) // Critical - can't process low res
        }
        let resolutionScore = min(resolution / 2000.0, 1.0) // Normalized to 2000px
        scores.append(resolutionScore)
        
        // 2. Analyze text recognition (most important for receipts)
        let textAnalysis = await analyzeText(in: cgImage)
        
        if textAnalysis.blockCount < minimumTextBlocks {
            warnings.append(.insufficientText)
        }
        
        if textAnalysis.averageConfidence < minimumTextConfidence {
            warnings.append(.poorTextQuality)
        }
        
        if !textAnalysis.hasNumbers {
            warnings.append(.noNumbers)
        }
        
        // Text score weighted heavily (50% of total)
        let textBlockScore = min(Double(textAnalysis.blockCount) / 30.0, 1.0)
        let textScore = (textAnalysis.averageConfidence * 0.4) + 
                       (textBlockScore * 0.3) +
                       (textAnalysis.hasNumbers ? 0.3 : 0.0)
        scores.append(textScore * 2.0) // Double weight for text
        
        // 3. Check sharpness/blur
        let sharpness = await analyzeSharpness(cgImage)
        if sharpness < minimumSharpness {
            warnings.append(.tooBlurry)
        }
        scores.append(sharpness)
        
        // 4. Check contrast and lighting
        let contrast = analyzeContrast(cgImage)
        if contrast < minimumContrast {
            warnings.append(.lowContrast)
        }
        scores.append(contrast)
        
        // 5. Analyze brightness/lighting
        let brightness = analyzeBrightness(cgImage)
        if brightness < 0.15 || brightness > 0.95 {
            warnings.append(.poorLighting)
        }
        let brightnessScore = 1.0 - abs(brightness - 0.5) * 2.0 // Optimal at 50%
        scores.append(brightnessScore)
        
        // Calculate overall quality score
        let overallScore = scores.reduce(0.0, +) / Double(scores.count)
        
        // Accept if: overall score is good AND no critical issues
        // Warnings are informational but don't block if score is good
        let isAcceptable = overallScore >= minimumQualityScore && criticalIssues.isEmpty
        
        // Combine all issues for reporting (critical + warnings)
        let allIssues = criticalIssues + warnings
        
        return ReceiptQualityResult(
            isAcceptable: isAcceptable,
            qualityScore: overallScore,
            issues: allIssues,
            textConfidence: textAnalysis.averageConfidence,
            detectedTextBlocks: textAnalysis.blockCount,
            hasNumericContent: textAnalysis.hasNumbers
        )
    }
    
    // MARK: - Text Analysis
    
    private struct TextAnalysis {
        let blockCount: Int
        let averageConfidence: Double
        let hasNumbers: Bool
        let hasCurrencySymbols: Bool
    }
    
    private func analyzeText(in cgImage: CGImage) async -> TextAnalysis {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: TextAnalysis(
                        blockCount: 0,
                        averageConfidence: 0.0,
                        hasNumbers: false,
                        hasCurrencySymbols: false
                    ))
                    return
                }
                
                var totalConfidence: Float = 0.0
                var hasNumbers = false
                var hasCurrencySymbols = false
                var validBlocks = 0
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    // Only count blocks with reasonable confidence
                    if topCandidate.confidence > 0.3 {
                        validBlocks += 1
                        totalConfidence += topCandidate.confidence
                        
                        let text = topCandidate.string
                        
                        // Check for numbers (prices, quantities, etc.)
                        if text.rangeOfCharacter(from: .decimalDigits) != nil {
                            hasNumbers = true
                        }
                        
                        // Check for currency symbols (€, $, £, etc.)
                        if text.contains("€") || text.contains("$") || 
                           text.contains("£") || text.contains("EUR") {
                            hasCurrencySymbols = true
                        }
                    }
                }
                
                let avgConfidence = validBlocks > 0 ? Double(totalConfidence) / Double(validBlocks) : 0.0
                
                continuation.resume(returning: TextAnalysis(
                    blockCount: validBlocks,
                    averageConfidence: avgConfidence,
                    hasNumbers: hasNumbers,
                    hasCurrencySymbols: hasCurrencySymbols
                ))
            }
            
            // Use accurate recognition for better quality assessment
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.02 // Detect smaller text typical in receipts
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: TextAnalysis(
                    blockCount: 0,
                    averageConfidence: 0.0,
                    hasNumbers: false,
                    hasCurrencySymbols: false
                ))
            }
        }
    }
    
    // MARK: - Sharpness Analysis
    
    private func analyzeSharpness(_ cgImage: CGImage) async -> Double {
        // Use Laplacian variance method - higher variance = sharper image
        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data,
              let pixels = CFDataGetBytePtr(pixelData) else {
            return 0.0
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        // Sample points for performance (every 4th pixel)
        var laplacianVariance: Double = 0.0
        var sampleCount = 0
        
        for y in stride(from: 4, to: height - 4, by: 4) {
            for x in stride(from: 4, to: width - 4, by: 4) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let center = Double(pixels[offset])
                
                // Calculate Laplacian using 4-neighbor kernel
                let top = Double(pixels[(y - 2) * bytesPerRow + x * bytesPerPixel])
                let bottom = Double(pixels[(y + 2) * bytesPerRow + x * bytesPerPixel])
                let left = Double(pixels[y * bytesPerRow + (x - 2) * bytesPerPixel])
                let right = Double(pixels[y * bytesPerRow + (x + 2) * bytesPerPixel])
                
                let laplacian = abs(4 * center - top - bottom - left - right)
                laplacianVariance += laplacian
                sampleCount += 1
            }
        }
        
        let averageVariance = sampleCount > 0 ? laplacianVariance / Double(sampleCount) : 0.0
        
        // Normalize to 0-1 range (typical range is 0-150 for receipts)
        return min(averageVariance / 150.0, 1.0)
    }
    
    // MARK: - Contrast Analysis
    
    private func analyzeContrast(_ cgImage: CGImage) -> Double {
        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data,
              let pixels = CFDataGetBytePtr(pixelData) else {
            return 0.0
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        // Sample brightness values
        var brightnessValues: [Double] = []
        let totalPixels = width * height
        let sampleStep = max(totalPixels / 2000, 1) // Sample ~2000 pixels
        
        for i in stride(from: 0, to: totalPixels, by: sampleStep) {
            let y = i / width
            let x = i % width
            
            guard y < height else { break }
            
            let offset = y * bytesPerRow + x * bytesPerPixel
            brightnessValues.append(Double(pixels[offset]))
        }
        
        guard !brightnessValues.isEmpty else { return 0.0 }
        
        // Calculate standard deviation (higher = better contrast)
        let mean = brightnessValues.reduce(0.0, +) / Double(brightnessValues.count)
        let variance = brightnessValues.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(brightnessValues.count)
        let standardDeviation = sqrt(variance)
        
        // Normalize (good receipt contrast typically has stdDev of 40-80)
        return min(standardDeviation / 80.0, 1.0)
    }
    
    // MARK: - Brightness Analysis
    
    private func analyzeBrightness(_ cgImage: CGImage) -> Double {
        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data,
              let pixels = CFDataGetBytePtr(pixelData) else {
            return 0.5
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        var totalBrightness: Double = 0.0
        let totalPixels = width * height
        let sampleStep = max(totalPixels / 1000, 1) // Sample ~1000 pixels
        var sampleCount = 0
        
        for i in stride(from: 0, to: totalPixels, by: sampleStep) {
            let y = i / width
            let x = i % width
            
            guard y < height else { break }
            
            let offset = y * bytesPerRow + x * bytesPerPixel
            totalBrightness += Double(pixels[offset])
            sampleCount += 1
        }
        
        let averageBrightness = sampleCount > 0 ? totalBrightness / Double(sampleCount) : 127.5
        
        // Normalize to 0-1 range
        return averageBrightness / 255.0
    }
}

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
        case noCurrencyOrTotal = "No prices found. Make sure the receipt total is visible."
        case noReceiptPattern = "This doesn't look like a receipt. Make sure the receipt text is clearly visible."
        case textNotReadable = "Cannot read text on receipt. Ensure good lighting and hold steady."
    }
}

/// Service for checking receipt image quality using Apple Vision framework
actor ReceiptQualityChecker {
    
    // MARK: - Quality Thresholds

    private let minimumQualityScore: Double = 0.60  // Minimum overall score (60%)
    private let minimumTextBlocks: Int = 8          // At least 8 readable text blocks (receipts have many lines)
    private let minimumTextConfidence: Double = 0.6  // 60% average confidence (stricter for readability)
    private let minimumSharpness: Double = 0.35      // Sharpness threshold
    private let minimumContrast: Double = 0.25       // Contrast threshold
    private let minimumResolution: CGFloat = 600     // Minimum width/height in pixels
    private let minimumPricePatterns: Int = 2        // At least 2 price-like patterns required
    
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
        // This is CRITICAL - if we can't read the text, we can't process the receipt
        let textAnalysis = await analyzeText(in: cgImage)

        // CRITICAL: Must have enough readable text blocks
        if textAnalysis.blockCount < minimumTextBlocks {
            criticalIssues.append(.insufficientText)
        }

        // CRITICAL: Text must be readable with good confidence
        if textAnalysis.averageConfidence < minimumTextConfidence {
            criticalIssues.append(.poorTextQuality)
        }

        // CRITICAL: Must have price patterns (this IS a receipt after all)
        if textAnalysis.pricePatternCount < minimumPricePatterns {
            criticalIssues.append(.noCurrencyOrTotal)
        }

        // CRITICAL: Need high-confidence blocks to ensure text is truly readable
        if textAnalysis.highConfidenceBlocks < 5 {
            criticalIssues.append(.textNotReadable)
        }

        // Warning: No numbers at all is suspicious
        if !textAnalysis.hasNumbers {
            warnings.append(.noNumbers)
        }

        // Warning: No receipt keywords (not critical, some receipts may not have "total")
        if !textAnalysis.hasReceiptKeywords && !textAnalysis.hasCurrencySymbols {
            warnings.append(.noReceiptPattern)
        }

        // Text score weighted heavily (50% of total)
        let textBlockScore = min(Double(textAnalysis.blockCount) / 30.0, 1.0)
        let highConfidenceScore = min(Double(textAnalysis.highConfidenceBlocks) / 15.0, 1.0)
        let pricePatternScore = min(Double(textAnalysis.pricePatternCount) / 5.0, 1.0)
        let textScore = (textAnalysis.averageConfidence * 0.25) +
                       (textBlockScore * 0.2) +
                       (highConfidenceScore * 0.25) +
                       (pricePatternScore * 0.2) +
                       (textAnalysis.textCoverageScore * 0.1)
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
        let pricePatternCount: Int      // Count of price-like patterns (e.g., "12.99", "€5.00")
        let hasReceiptKeywords: Bool     // "total", "subtotal", "tax", etc.
        let textCoverageScore: Double    // How much of the image contains text (0-1)
        let highConfidenceBlocks: Int    // Blocks with >70% confidence
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
                        hasCurrencySymbols: false,
                        pricePatternCount: 0,
                        hasReceiptKeywords: false,
                        textCoverageScore: 0.0,
                        highConfidenceBlocks: 0
                    ))
                    return
                }

                var totalConfidence: Float = 0.0
                var hasNumbers = false
                var hasCurrencySymbols = false
                var validBlocks = 0
                var highConfidenceBlocks = 0
                var pricePatternCount = 0
                var hasReceiptKeywords = false

                // For text coverage calculation
                var totalTextArea: Double = 0.0

                // Price pattern regex: matches formats like "12.99", "€5.00", "$10", "1,99", etc.
                let pricePattern = try? NSRegularExpression(
                    pattern: #"(?:€|\$|£|EUR|USD|GBP)?\s*\d+[.,]\d{2}|\d+[.,]\d{2}\s*(?:€|\$|£|EUR)?"#,
                    options: [.caseInsensitive]
                )

                // Receipt keywords (common across languages)
                let receiptKeywords = [
                    "total", "totaal", "subtotal", "tax", "btw", "vat", "tva",
                    "amount", "bedrag", "sum", "som", "change", "wisselgeld",
                    "cash", "card", "visa", "mastercard", "maestro", "bancontact",
                    "receipt", "bon", "ticket", "invoice", "factuur", "qty", "quantity"
                ]

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    let confidence = topCandidate.confidence
                    let text = topCandidate.string.lowercased()

                    // Only count blocks with reasonable confidence
                    if confidence > 0.3 {
                        validBlocks += 1
                        totalConfidence += confidence

                        // Count high confidence blocks (>70%) - these are clearly readable
                        if confidence > 0.7 {
                            highConfidenceBlocks += 1
                        }

                        // Calculate text area for coverage
                        let boundingBox = observation.boundingBox
                        totalTextArea += Double(boundingBox.width * boundingBox.height)

                        // Check for numbers (prices, quantities, etc.)
                        if text.rangeOfCharacter(from: .decimalDigits) != nil {
                            hasNumbers = true
                        }

                        // Check for currency symbols (€, $, £, etc.)
                        if text.contains("€") || text.contains("$") ||
                           text.contains("£") || text.contains("eur") {
                            hasCurrencySymbols = true
                        }

                        // Check for price patterns
                        if let regex = pricePattern {
                            let range = NSRange(text.startIndex..., in: text)
                            pricePatternCount += regex.numberOfMatches(in: text, options: [], range: range)
                        }

                        // Check for receipt keywords
                        for keyword in receiptKeywords {
                            if text.contains(keyword) {
                                hasReceiptKeywords = true
                                break
                            }
                        }
                    }
                }

                let avgConfidence = validBlocks > 0 ? Double(totalConfidence) / Double(validBlocks) : 0.0

                // Text coverage: what fraction of the image has readable text
                // Good receipts typically have 5-20% text coverage
                let textCoverageScore = min(totalTextArea / 0.15, 1.0) // Normalize against 15% coverage

                continuation.resume(returning: TextAnalysis(
                    blockCount: validBlocks,
                    averageConfidence: avgConfidence,
                    hasNumbers: hasNumbers,
                    hasCurrencySymbols: hasCurrencySymbols,
                    pricePatternCount: pricePatternCount,
                    hasReceiptKeywords: hasReceiptKeywords,
                    textCoverageScore: textCoverageScore,
                    highConfidenceBlocks: highConfidenceBlocks
                ))
            }

            // Use accurate recognition for better quality assessment
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.015 // Detect smaller text typical in receipts

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: TextAnalysis(
                    blockCount: 0,
                    averageConfidence: 0.0,
                    hasNumbers: false,
                    hasCurrencySymbols: false,
                    pricePatternCount: 0,
                    hasReceiptKeywords: false,
                    textCoverageScore: 0.0,
                    highConfidenceBlocks: 0
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

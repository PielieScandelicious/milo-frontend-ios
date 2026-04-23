//
//  BarcodeGenerator.swift
//  Scandalicious
//
//  Native on-device barcode rendering for coupons. The user sees a pixel-perfect
//  barcode on the phone screen that the till scanner reads directly — no image
//  upscaling, no blurry crops, no dependency on the source folder's resolution.
//
//  Supported formats:
//    - EAN-13 / UPC-A (compatible when EAN-13 starts with "0") — pure-Swift
//      encoder below (GS1 spec). Self-contained, no third-party dependency.
//    - Code-128 via CoreImage's built-in `CIFilter.code128BarcodeGenerator()`.
//
//  If we ever want to swap the EAN-13 path to an SPM package (e.g. CoreBarcodes,
//  BarcodeKit), the call site only interacts with `BarcodeGenerator.image(...)`
//  so the internal implementation can be replaced without touching the UI.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum BarcodeFormat: String {
    case ean13
    case code128
    case unknown

    /// Map the backend's `coupon_barcode_format` string to our enum.
    /// Unknown formats fall back to `.unknown` which yields `nil` from the generator
    /// — the UI should then hide the barcode section rather than show garbage.
    static func from(backendFormat: String?) -> BarcodeFormat {
        switch backendFormat {
        case "EAN-13", "UPC-A": return .ean13  // UPC-A is EAN-13 with a leading 0
        case "Code-128": return .code128
        default: return .unknown
        }
    }
}

enum BarcodeGenerator {

    // MARK: - Public API

    /// Render a barcode as a UIImage sized to fit the given `size`, at the given
    /// screen scale. Returns nil if the input is invalid (checksum mismatch,
    /// unsupported format, etc.).
    static func image(for value: String, format: BarcodeFormat, size: CGSize, scale: CGFloat) -> UIImage? {
        let cacheKey = "\(format.rawValue):\(value):\(Int(size.width))x\(Int(size.height))@\(scale)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let image: UIImage?
        switch format {
        case .ean13:   image = renderEAN13(digits: value, size: size, scale: scale)
        case .code128: image = renderCode128(value: value, size: size, scale: scale)
        case .unknown: image = nil
        }

        if let image = image {
            cache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    // MARK: - Internals

    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 64   // enough to hold every coupon the user has saved
        return c
    }()

    // MARK: Code-128 (CoreImage)

    private static func renderCode128(value: String, size: CGSize, scale: CGFloat) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        guard let data = value.data(using: .ascii) else { return nil }
        filter.message = data
        filter.quietSpace = 7
        guard let ci = filter.outputImage else { return nil }
        return rasterize(ci: ci, targetSize: size, scale: scale)
    }

    // MARK: EAN-13 (pure Swift, GS1 spec)

    private static func renderEAN13(digits: String, size: CGSize, scale: CGFloat) -> UIImage? {
        let cleaned = digits.filter { $0.isNumber }
        guard cleaned.count == 13, isValidEAN13Checksum(cleaned) else { return nil }

        let pattern = ean13BarPattern(for: cleaned)  // 95-bit string of "1" (bar) / "0" (space)
        // Render the pattern at a clean integer module width first, then scale to the
        // target size using nearest-neighbor so bars stay crisp and equal-width.
        let modules = pattern.count  // 95
        let moduleWidthPx = 2        // intrinsic bitmap module width (arbitrary; scaled later)
        let hriHeightPx = 20         // space reserved for human-readable digits
        let barHeightPx = 80
        let intrinsicWidth = modules * moduleWidthPx
        let intrinsicHeight = barHeightPx + hriHeightPx

        let imgSize = CGSize(width: intrinsicWidth, height: intrinsicHeight)
        UIGraphicsBeginImageContextWithOptions(imgSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: imgSize))

        ctx.setFillColor(UIColor.black.cgColor)
        for (i, ch) in pattern.enumerated() where ch == "1" {
            ctx.fill(CGRect(x: i * moduleWidthPx, y: 0, width: moduleWidthPx, height: barHeightPx))
        }

        // Human-readable digits. EAN-13 convention: first digit left of the bars,
        // digits 2–7 below the left half, digits 8–13 below the right half.
        let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let hriY = barHeightPx + 2
        let lead = String(cleaned.prefix(1))
        let leftGroup = String(cleaned.dropFirst(1).prefix(6))
        let rightGroup = String(cleaned.suffix(6))
        (lead as NSString).draw(at: CGPoint(x: 0, y: hriY), withAttributes: attrs)
        (leftGroup as NSString).draw(at: CGPoint(x: 3 * moduleWidthPx + 6, y: hriY), withAttributes: attrs)
        (rightGroup as NSString).draw(at: CGPoint(x: 50 * moduleWidthPx + 6, y: hriY), withAttributes: attrs)

        guard let intrinsic = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        return rasterize(uiImage: intrinsic, targetSize: size, scale: scale)
    }

    // MARK: Common rasterization — upscale crisply to the target drawing size.

    private static func rasterize(ci: CIImage, targetSize: CGSize, scale: CGFloat) -> UIImage? {
        let sx = targetSize.width / ci.extent.width
        let sy = targetSize.height / ci.extent.height
        let s = min(sx, sy)
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: s, y: s))
        let rect = scaled.extent.integral
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: rect.size))
            UIImage(ciImage: scaled).draw(in: CGRect(origin: .zero, size: rect.size))
        }
    }

    private static func rasterize(uiImage: UIImage, targetSize: CGSize, scale: CGFloat) -> UIImage? {
        guard let cg = uiImage.cgImage else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        // Nearest-neighbor interpolation keeps bars crisp when the intrinsic bitmap
        // is upscaled to the final display size.
        return renderer.image { rctx in
            rctx.cgContext.interpolationQuality = .none
            UIColor.white.setFill()
            rctx.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            // CGContext y-axis is flipped relative to UIImage; flip once so the
            // bars draw right-side up.
            rctx.cgContext.saveGState()
            rctx.cgContext.translateBy(x: 0, y: targetSize.height)
            rctx.cgContext.scaleBy(x: 1, y: -1)
            rctx.cgContext.draw(cg, in: CGRect(origin: .zero, size: targetSize))
            rctx.cgContext.restoreGState()
        }
    }

    // MARK: EAN-13 encoding tables (GS1 spec)

    /// Parity pattern selector for the 6 left-side digits, indexed by the first digit.
    /// "L" → L-code (odd parity), "G" → G-code (even parity).
    private static let ean13LeadingParity: [[Character]] = [
        ["L","L","L","L","L","L"], // 0
        ["L","L","G","L","G","G"], // 1
        ["L","L","G","G","L","G"], // 2
        ["L","L","G","G","G","L"], // 3
        ["L","G","L","L","G","G"], // 4
        ["L","G","G","L","L","G"], // 5
        ["L","G","G","G","L","L"], // 6
        ["L","G","L","G","L","G"], // 7
        ["L","G","L","G","G","L"], // 8
        ["L","G","G","L","G","L"], // 9
    ]

    // L-codes (odd parity, used on the left when parity is "L").
    private static let ean13LCode = [
        "0001101","0011001","0010011","0111101","0100011",
        "0110001","0101111","0111011","0110111","0001011",
    ]
    // G-codes (even parity, used on the left when parity is "G").
    private static let ean13GCode = [
        "0100111","0110011","0011011","0100001","0011101",
        "0111001","0000101","0010001","0001001","0010111",
    ]
    // R-codes (always used on the right).
    private static let ean13RCode = [
        "1110010","1100110","1101100","1000010","1011100",
        "1001110","1010000","1000100","1001000","1110100",
    ]

    private static func ean13BarPattern(for digits: String) -> String {
        let ds = digits.compactMap { Int(String($0)) }
        guard ds.count == 13 else { return "" }
        let firstDigit = ds[0]
        let leftDigits = Array(ds[1...6])
        let rightDigits = Array(ds[7...12])
        let parity = ean13LeadingParity[firstDigit]

        var bars = "101"  // left guard
        for (i, d) in leftDigits.enumerated() {
            bars += (parity[i] == "L") ? ean13LCode[d] : ean13GCode[d]
        }
        bars += "01010"  // center guard
        for d in rightDigits {
            bars += ean13RCode[d]
        }
        bars += "101"  // right guard
        return bars
    }

    private static func isValidEAN13Checksum(_ digits: String) -> Bool {
        let ds = digits.compactMap { Int(String($0)) }
        guard ds.count == 13 else { return false }
        var sum = 0
        for i in 0..<12 {
            sum += ds[i] * (i.isMultiple(of: 2) ? 1 : 3)
        }
        let check = (10 - sum % 10) % 10
        return check == ds[12]
    }
}

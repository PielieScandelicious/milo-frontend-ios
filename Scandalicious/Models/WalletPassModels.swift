//
//  WalletPassModels.swift
//  Scandalicious
//
//  Created for Wallet Pass Creator feature
//

import Foundation
import SwiftUI

// MARK: - Barcode Types
enum WalletBarcodeType: String, CaseIterable, Identifiable {
    case qr = "PKBarcodeFormatQR"
    case pdf417 = "PKBarcodeFormatPDF417"
    case aztec = "PKBarcodeFormatAztec"
    case code128 = "PKBarcodeFormatCode128"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qr: return "QR Code"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .code128: return "Code 128"
        }
    }

    var iconName: String {
        switch self {
        case .qr: return "qrcode"
        case .pdf417: return "barcode"
        case .aztec: return "viewfinder"
        case .code128: return "barcode"
        }
    }
}

// MARK: - Pass Color Presets
struct PassColorPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let backgroundColor: Color
    let foregroundColor: Color
    let labelColor: Color

    static let presets: [PassColorPreset] = [
        PassColorPreset(
            name: "Midnight",
            backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.15),
            foregroundColor: .white,
            labelColor: Color(white: 0.7)
        ),
        PassColorPreset(
            name: "Ocean",
            backgroundColor: Color(red: 0.0, green: 0.4, blue: 0.7),
            foregroundColor: .white,
            labelColor: Color(white: 0.85)
        ),
        PassColorPreset(
            name: "Forest",
            backgroundColor: Color(red: 0.15, green: 0.5, blue: 0.35),
            foregroundColor: .white,
            labelColor: Color(white: 0.85)
        ),
        PassColorPreset(
            name: "Sunset",
            backgroundColor: Color(red: 0.9, green: 0.4, blue: 0.2),
            foregroundColor: .white,
            labelColor: Color(white: 0.9)
        ),
        PassColorPreset(
            name: "Berry",
            backgroundColor: Color(red: 0.6, green: 0.2, blue: 0.5),
            foregroundColor: .white,
            labelColor: Color(white: 0.85)
        ),
        PassColorPreset(
            name: "Slate",
            backgroundColor: Color(red: 0.35, green: 0.4, blue: 0.45),
            foregroundColor: .white,
            labelColor: Color(white: 0.8)
        ),
        PassColorPreset(
            name: "Ruby",
            backgroundColor: Color(red: 0.75, green: 0.15, blue: 0.25),
            foregroundColor: .white,
            labelColor: Color(white: 0.85)
        ),
        PassColorPreset(
            name: "Gold",
            backgroundColor: Color(red: 0.85, green: 0.65, blue: 0.2),
            foregroundColor: Color(red: 0.2, green: 0.15, blue: 0.1),
            labelColor: Color(red: 0.4, green: 0.3, blue: 0.15)
        ),
        PassColorPreset(
            name: "Snow",
            backgroundColor: Color(white: 0.95),
            foregroundColor: Color(red: 0.15, green: 0.15, blue: 0.2),
            labelColor: Color(white: 0.4)
        ),
        PassColorPreset(
            name: "Charcoal",
            backgroundColor: Color(red: 0.2, green: 0.2, blue: 0.22),
            foregroundColor: .white,
            labelColor: Color(white: 0.6)
        )
    ]
}

// MARK: - Loyalty Pass Data
struct LoyaltyPassData {
    var storeName: String = ""
    var barcodeValue: String = ""
    var barcodeType: WalletBarcodeType = .qr
    var colorPreset: PassColorPreset = PassColorPreset.presets[0]
    var logoImage: UIImage? = nil
    var stripImage: UIImage? = nil

    var isValid: Bool {
        !storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Detected Barcode
struct DetectedBarcode: Identifiable, Equatable {
    let id = UUID()
    let value: String
    let type: WalletBarcodeType
    let bounds: CGRect

    static func == (lhs: DetectedBarcode, rhs: DetectedBarcode) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value && lhs.type == rhs.type
    }
}

// MARK: - Pass Creation State
enum PassCreationState: Equatable {
    case idle
    case creatingPass
    case passReady(URL)
    case error(String)

    static func == (lhs: PassCreationState, rhs: PassCreationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.creatingPass, .creatingPass): return true
        case (.passReady(let lhsURL), .passReady(let rhsURL)): return lhsURL == rhsURL
        case (.error(let lhsMsg), .error(let rhsMsg)): return lhsMsg == rhsMsg
        default: return false
        }
    }
}

//
//  CategorySymbolImage.swift
//  Scandalicious
//

import SwiftUI

/// Names of custom SF Symbol assets in the asset catalog.
/// These are NOT system SF Symbols and must be loaded with `Image(_:)` instead of `Image(systemName:)`.
private let customSymbolNames: Set<String> = [
    "custom.apple.fill",
    "custom.cheese.fill",
    "custom.steak.fill",
]

extension Image {
    /// Creates an Image from either a system SF Symbol or a custom symbol in the asset catalog.
    /// Use this instead of `Image(systemName:)` when the icon name may refer to a custom symbol.
    static func categorySymbol(_ name: String) -> Image {
        if customSymbolNames.contains(name) {
            return Image(name)
        }
        return Image(systemName: name)
    }
}

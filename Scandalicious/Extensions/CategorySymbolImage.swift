//
//  CategorySymbolImage.swift
//  Scandalicious
//

import SwiftUI
import PhosphorSwift

extension Image {
    /// Creates a resizable, template-rendered icon from a Phosphor icon name (kebab-case)
    /// or falls back to an SF Symbol. Use `.frame(width:height:)` for sizing and
    /// `.foregroundStyle()` for coloring.
    @ViewBuilder
    static func categorySymbol(_ name: String) -> some View {
        if let phIcon = Ph(rawValue: name) {
            phIcon.fill
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

//
//  ValidityChip.swift
//  Scandalicious
//
//  Compact countdown chip ("Nog 3 dagen", "Laatste dag!", "Verlopen").
//  Colour + icon come from PromoValidity.display so urgency is applied
//  identically on every surface.
//

import SwiftUI

struct ValidityChip: View {
    let validityEnd: String
    var compact: Bool = false

    var body: some View {
        let d = PromoValidity.display(for: validityEnd)
        HStack(spacing: compact ? 3 : 4) {
            if let icon = d.icon {
                Image(systemName: icon)
                    .font(.system(size: compact ? 8 : 10, weight: .semibold))
            }
            Text(d.text)
                .font(.system(size: compact ? 9 : 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(d.color)
        .accessibilityLabel(d.text)
    }
}

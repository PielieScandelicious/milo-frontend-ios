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

    var body: some View {
        let d = PromoValidity.display(for: validityEnd)
        HStack(spacing: 4) {
            if let icon = d.icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(d.text)
                .font(PromoDesign.chip())
                .lineLimit(1)
        }
        .foregroundStyle(d.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: PromoDesign.chipCorner, style: .continuous)
                .fill(d.color.opacity(0.15))
        )
        .accessibilityLabel(d.text)
    }
}

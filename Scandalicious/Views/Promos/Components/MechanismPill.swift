//
//  MechanismPill.swift
//  Scandalicious
//
//  Coloured pill driven by MechanismKind. Consistent across every promo
//  surface — users learn the colour language (gold = gratis, green = %
//  off, purple = bundle, blue = prijsverlaging).
//

import SwiftUI

struct MechanismPill: View {
    let text: String
    let kind: MechanismKind

    init(text: String, kind: MechanismKind) {
        self.text = text
        self.kind = kind
    }

    init(item: PromoStoreItem) {
        self.text = item.mechanismLabel
        self.kind = .from(displayMechanism: item.displayMechanism, mechanism: item.mechanism)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.iconName)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(kind.textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: PromoDesign.pillCorner, style: .continuous)
                .fill(kind.color)
        )
        .accessibilityLabel(text)
    }
}

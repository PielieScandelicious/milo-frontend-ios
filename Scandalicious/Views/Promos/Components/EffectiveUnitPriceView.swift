//
//  EffectiveUnitPriceView.swift
//  Scandalicious
//
//  The cross-store comparison anchor. Renders the effective post-promo
//  €/kg (or €/L, €/stuk, €/rol) in consistent typography everywhere it
//  appears. If the backend didn't compute a unit price (low quality,
//  missing, invalid, or price_unavailable) this view renders nothing.
//

import SwiftUI

struct EffectiveUnitPriceView: View {
    enum Size { case card, hero }

    let item: PromoStoreItem
    let size: Size

    private var canRender: Bool {
        guard !item.priceUnavailable else { return false }
        // Prefer the string the backend already formatted; fall back to numeric.
        if let s = item.displayUnitPrice, !s.isEmpty { return true }
        if let value = item.unitPriceValue, value > 0, item.unitPriceUnit != nil { return true }
        return false
    }

    private var text: String {
        if let s = item.displayUnitPrice, !s.isEmpty { return s }
        if let value = item.unitPriceValue, let unit = item.unitPriceUnit {
            return String(format: "€%.2f/%@", value, unit == "l" ? "L" : unit)
        }
        return ""
    }

    var body: some View {
        if canRender {
            let font: Font = (size == .hero) ? PromoDesign.heroPrice() : PromoDesign.unitPrice()
            Text(text)
                .font(font)
                .foregroundStyle(PromoDesign.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()
                .accessibilityLabel("Prijs per eenheid: \(text)")
        }
    }
}

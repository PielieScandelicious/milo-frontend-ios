//
//  PromoPriceStack.swift
//  Scandalicious
//
//  Renders the pack-price line: big promo_price + struck-through original.
//  When `price_unavailable` is true (assortment tiles), renders an italic
//  "Prijs in winkel" string instead — never fake €0.00.
//

import SwiftUI

struct PromoPriceStack: View {
    enum Size { case card, hero }

    let item: PromoStoreItem
    let size: Size

    private var promoFont: Font { size == .hero ? PromoDesign.heroPrice() : PromoDesign.cardPrice() }
    private var strikeFont: Font { size == .hero ? PromoDesign.unitPrice() : PromoDesign.strikePrice() }

    var body: some View {
        if item.priceUnavailable {
            Text("Prijs in winkel")
                .font(.system(size: size == .hero ? 20 : 16, weight: .semibold, design: .rounded))
                .italic()
                .foregroundStyle(PromoDesign.secondaryText)
                .accessibilityLabel("Prijs in winkel")
        } else if item.hasPrices {
            // `lineLimit(1)` + `minimumScaleFactor` keep the promo + struck
            // original on a single line even when the hero price is wide
            // (e.g. "€14.99" + "€19.99") and shares the row with a savings
            // pill on a compact iPhone.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(promoFont)
                    .foregroundStyle(PromoDesign.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if item.originalPrice > item.promoPrice {
                    Text(String(format: "€%.2f", item.originalPrice))
                        .font(strikeFont)
                        .foregroundStyle(PromoDesign.tertiaryText)
                        .strikethrough(true, color: PromoDesign.tertiaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var accessibilityLabel: String {
        if item.originalPrice > item.promoPrice {
            return String(format: "Promotieprijs €%.2f, normale prijs €%.2f", item.promoPrice, item.originalPrice)
        }
        return String(format: "Prijs €%.2f", item.promoPrice)
    }
}

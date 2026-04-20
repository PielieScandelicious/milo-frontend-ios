//
//  CrossStoreComparisonView.swift
//  Scandalicious
//
//  Horizontal bar chart showing the SAME product's effective €/unit at other
//  retailers. Built on top of the similar-promos endpoint: we filter to rows
//  that share the current item's brand + canonical unit so the comparison is
//  apples-to-apples (you don't compare €/kg vs €/L).
//

import SwiftUI

struct CrossStoreComparisonView: View {
    let current: PromoStoreItem
    let currentStoreName: String
    let siblings: [PromoStoreItem]
    let onTap: (PromoStoreItem) -> Void

    private struct Row: Identifiable {
        let id: String
        let item: PromoStoreItem
        let storeName: String
        let unitPrice: Double
        let unit: String
        let isCurrent: Bool
    }

    /// Filter + sort siblings into comparable rows.
    private var rows: [Row] {
        // Anchor values from the current item (need a unit-price to compare).
        guard !current.priceUnavailable,
              let currentUnit = current.unitPriceUnit,
              let currentValue = current.unitPriceValue, currentValue > 0 else {
            return []
        }
        let brandKey = current.brand.trimmingCharacters(in: .whitespaces).lowercased()
        guard !brandKey.isEmpty else { return [] }

        var built: [Row] = [
            Row(id: current.id + ":self",
                item: current, storeName: currentStoreName,
                unitPrice: currentValue, unit: currentUnit, isCurrent: true)
        ]

        for sibling in siblings {
            guard !sibling.priceUnavailable,
                  let unit = sibling.unitPriceUnit, unit == currentUnit,
                  let value = sibling.unitPriceValue, value > 0 else { continue }
            let siblingBrand = sibling.brand.trimmingCharacters(in: .whitespaces).lowercased()
            guard siblingBrand == brandKey else { continue }
            let siblingStore = sibling.storeName ?? ""
            guard !siblingStore.isEmpty, siblingStore.lowercased() != currentStoreName.lowercased() else { continue }
            built.append(
                Row(id: sibling.id, item: sibling, storeName: siblingStore,
                    unitPrice: value, unit: unit, isCurrent: false)
            )
        }

        // Need at least one OTHER retailer for a comparison to be meaningful.
        guard built.count >= 2 else { return [] }
        return built.sorted { $0.unitPrice < $1.unitPrice }
    }

    var body: some View {
        let data = rows
        if !data.isEmpty, let maxPrice = data.map({ $0.unitPrice }).max(), maxPrice > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 12, weight: .semibold))
                    Text("VERGELIJK BIJ ANDERE WINKELS")
                        .font(PromoDesign.eyebrow()).tracking(1.1)
                }
                .foregroundStyle(PromoDesign.secondaryText)

                VStack(spacing: 8) {
                    ForEach(data) { row in
                        comparisonRow(row, maxPrice: maxPrice, cheapest: data.first?.unitPrice ?? row.unitPrice)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func comparisonRow(_ row: Row, maxPrice: Double, cheapest: Double) -> some View {
        let widthFraction = max(0.18, CGFloat(row.unitPrice / maxPrice))
        let accent = GroceryStore.fromCanonical(row.storeName)?.accentColor ?? PromoDesign.accentGreen
        let isCheapest = abs(row.unitPrice - cheapest) < 0.001
        let savingsVsCheapest = row.unitPrice > cheapest
            ? Int(((row.unitPrice - cheapest) / row.unitPrice * 100).rounded())
            : 0

        Button { onTap(row.item) } label: {
            HStack(spacing: 10) {
                StoreLogoView(storeName: row.storeName, height: 22)
                    .frame(width: 32, height: 32)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(GroceryStore.fromCanonical(row.storeName)?.displayName ?? row.storeName.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(row.isCurrent ? PromoDesign.primaryText : PromoDesign.secondaryText)
                        if row.isCurrent {
                            Text("· DEZE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(accent)
                        } else if isCheapest {
                            Text("· GOEDKOOPST")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(PromoDesign.accentGreen)
                        } else if savingsVsCheapest > 0 {
                            Text("· \(savingsVsCheapest)% duurder")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(PromoDesign.tertiaryText)
                        }
                        Spacer(minLength: 4)
                    }

                    // Bar + price label on the right
                    GeometryReader { geo in
                        let maxWidth = geo.size.width - 70 // reserve 70pt for price label
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    isCheapest
                                        ? PromoDesign.accentGreen
                                        : accent.opacity(row.isCurrent ? 0.85 : 0.55)
                                )
                                .frame(width: max(12, maxWidth * widthFraction), height: 10)
                        }
                        .overlay(alignment: .trailing) {
                            Text(String(format: "€%.2f/%@", row.unitPrice, row.unit == "l" ? "L" : row.unit))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PromoDesign.primaryText)
                                .monospacedDigit()
                        }
                    }
                    .frame(height: 14)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

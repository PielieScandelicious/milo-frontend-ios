//
//  StoreBadge.swift
//  Scandalicious
//
//  Consistent store identity badge shown on every promo surface so users
//  can recognise "this deal is at Colruyt" at a glance.
//

import SwiftUI

struct StoreBadge: View {
    enum Size { case small, large }

    let storeName: String
    let size: Size

    private var store: GroceryStore? { GroceryStore.fromCanonical(storeName) }
    private var accent: Color { store?.accentColor ?? PromoDesign.accentGreen }
    private var displayName: String { store?.displayName ?? storeName.capitalized }

    var body: some View {
        HStack(spacing: size == .small ? 6 : 8) {
            StoreLogoView(storeName: storeName, height: size == .small ? 18 : 26)
            if size == .large {
                Text(displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
        }
        .padding(.horizontal, size == .small ? 6 : 10)
        .padding(.vertical, size == .small ? 4 : 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous).stroke(accent.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

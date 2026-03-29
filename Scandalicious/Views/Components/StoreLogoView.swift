//
//  StoreLogoView.swift
//  Scandalicious
//
//  Reusable store logo component that resolves a store name to its SVG logo.
//

import SwiftUI

struct StoreLogoView: View {
    let storeName: String
    var height: CGFloat = 24
    var fallbackColor: Color? = nil

    /// Match by canonical name first, then fall back to display name (case-insensitive).
    private var resolvedStore: GroceryStore? {
        GroceryStore.fromCanonical(storeName)
            ?? GroceryStore.allCases.first {
                $0.rawValue.caseInsensitiveCompare(storeName) == .orderedSame
            }
    }

    var body: some View {
        if let store = resolvedStore {
            Image(store.logoImageName)
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else if let color = fallbackColor {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                Text(String(storeName.prefix(1)).uppercased())
                    .font(.system(size: height * 0.5, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: height, height: height)
        }
    }
}

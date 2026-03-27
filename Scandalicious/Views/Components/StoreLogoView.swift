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

    /// Case-insensitive match: backend sends lowercase ("colruyt", "albert heijn")
    /// but GroceryStore rawValues are display names ("Colruyt", "Albert Heijn").
    private var resolvedStore: GroceryStore? {
        GroceryStore.allCases.first {
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

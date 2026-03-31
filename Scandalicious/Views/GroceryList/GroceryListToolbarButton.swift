//
//  GroceryListToolbarButton.swift
//  Scandalicious
//

import SwiftUI

/// Grocery list toolbar button — Apple-style, transparent background.
struct GroceryListToolbarButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "cart")
                    .font(.system(size: 17, weight: .semibold))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(.white)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
    }
}

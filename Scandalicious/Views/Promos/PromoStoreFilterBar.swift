//
//  PromoStoreFilterBar.swift
//  Scandalicious
//
//  Horizontal scrollable store filter chips for the promo grid.
//

import SwiftUI

struct PromoStoreFilterBar: View {
    @ObservedObject var viewModel: PromosViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                filterChip(
                    label: "All",
                    count: viewModel.totalFilteredCount,
                    isSelected: viewModel.selectedFilterStore == nil,
                    accentColor: filterGreen,
                    storeName: nil
                ) {
                    withAnimation(.smooth(duration: 0.25)) {
                        viewModel.selectedFilterStore = nil
                    }
                }

                // Per-store chips
                ForEach(viewModel.storeFilterOptions, id: \.name) { option in
                    let store = GroceryStore.fromCanonical(option.name)
                    let accent = store?.accentColor ?? filterGreen

                    filterChip(
                        label: store?.displayName ?? option.name.capitalized,
                        count: option.count,
                        isSelected: viewModel.selectedFilterStore == option.name,
                        accentColor: accent,
                        storeName: option.name
                    ) {
                        withAnimation(.smooth(duration: 0.25)) {
                            viewModel.selectedFilterStore = option.name
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func filterChip(
        label: String,
        count: Int,
        isSelected: Bool,
        accentColor: Color,
        storeName: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let name = storeName {
                    StoreLogoView(storeName: name, height: 14)
                        .frame(width: 20, height: 20)
                }

                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))

                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.35))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isSelected
                        ? accentColor.opacity(0.25)
                        : Color.white.opacity(0.06)
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected
                        ? accentColor.opacity(0.5)
                        : Color.white.opacity(0.08),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }
}

private let filterGreen = Color(red: 0.20, green: 0.85, blue: 0.50)

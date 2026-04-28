//
//  FolderSearchFilterSheet.swift
//  Scandalicious
//
//  Bottom sheet to scope the search to one or more retailers. Multi-select:
//  tapping a chip toggles it; tapping the "All stores" chip clears the set.
//  Stores are mapped by canonical name (matching the backend's
//  source_retailer column).
//

import SwiftUI

struct FolderSearchFilterSheet: View {
    @ObservedObject var viewModel: PromoSearchViewModel
    let availableStores: [GroceryStore]
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        allStoresChip

                        Text(L("promo_search_filter_store"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .padding(.top, 4)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(availableStores) { store in
                                storeChip(store)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(Text(L("promo_search_filter_store")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("done")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var allStoresChip: some View {
        let allSelected = viewModel.storeFilters.isEmpty
        return Button {
            viewModel.clearStoreFilters()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(L("promo_search_all_stores"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if allSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(allSelected ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(allSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: allSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func storeChip(_ store: GroceryStore) -> some View {
        let isSelected = viewModel.storeFilters.contains(store.canonicalName)
        return Button {
            viewModel.toggleStoreFilter(store.canonicalName)
        } label: {
            VStack(spacing: 6) {
                Image(store.logoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 60, maxHeight: 30)
                    .frame(height: 30)
                    .opacity(isSelected ? 1.0 : 0.75)
                Text(store.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? store.accentColor.opacity(0.22) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? store.accentColor.opacity(0.55) : Color.white.opacity(0.07),
                        lineWidth: isSelected ? 1.4 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    ZStack {
                        Circle().fill(store.accentColor).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(Color(white: 0.05), lineWidth: 2))
                    .offset(x: 7, y: -7)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

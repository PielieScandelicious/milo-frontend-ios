//
//  FolderSearchEmptyState.swift
//  Scandalicious
//
//  Content shown inside the focused search overlay when the query is empty:
//  the user's recent searches plus a horizontal chip strip of popular brands
//  (driven by `/promos/search/popular-brands`).
//

import SwiftUI

struct FolderSearchEmptyState: View {
    @ObservedObject var viewModel: PromoSearchViewModel
    @ObservedObject private var recents = RecentSearchesManager.shared

    let onPickQuery: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !recents.searches.isEmpty {
                recentSection
            }
            if !viewModel.popularBrands.isEmpty {
                brandsSection
            }
        }
    }

    // MARK: - Recent Searches

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("promo_search_recent"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Button {
                    recents.clear()
                } label: {
                    Text(L("promo_search_clear_recent"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.blue.opacity(0.9))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 4) {
                ForEach(recents.searches, id: \.self) { query in
                    recentRow(query)
                }
            }
        }
    }

    private func recentRow(_ query: String) -> some View {
        Button {
            onPickQuery(query)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 22)
                Text(query)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    recents.remove(query)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Popular Brands

    private var brandsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("promo_search_popular_brands"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(0.6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.popularBrands) { brand in
                        Button {
                            onPickQuery(brand.name)
                        } label: {
                            HStack(spacing: 6) {
                                Text(brand.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(brand.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous).fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

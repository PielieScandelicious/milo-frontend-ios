//
//  FolderSearchEmptyState.swift
//  Scandalicious
//
//  Content shown inside the focused search overlay when the query is empty:
//  the user's recent searches.
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
        }
        .padding(.top, 28)
    }

    // MARK: - Recent Searches

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("promo_search_recent"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.8)
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

            VStack(spacing: 0) {
                ForEach(Array(recents.searches.enumerated()), id: \.element) { idx, query in
                    recentRow(query)
                    if idx < recents.searches.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 0.5)
                            .padding(.leading, 34)
                    }
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

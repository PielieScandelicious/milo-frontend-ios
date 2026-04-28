//
//  FolderSearchOverlay.swift
//  Scandalicious
//
//  The full-screen panel that takes over the Folders tab when the search
//  bar is focused. Switches between empty / typing / loading / results /
//  no-results / error states based on the view model's `phase`.
//

import SwiftUI

struct FolderSearchOverlay: View {
    @ObservedObject var viewModel: PromoSearchViewModel
    /// Vertical padding so the overlay content starts below the floating
    /// search bar that lives above this view in the parent ZStack.
    let topInset: CGFloat
    let onPickQuery: (String) -> Void
    let onTapResult: (PromoStoreItem, Int) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            VerticalOnlyScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: topInset)

                    switch viewModel.phase {
                    case .empty:
                        FolderSearchEmptyState(
                            viewModel: viewModel,
                            onPickQuery: onPickQuery
                        )
                        .padding(.horizontal, 16)
                    case .tooShort:
                        tooShortHint
                            .padding(.horizontal, 16)
                    case .loading:
                        skeletonRows
                    case .results:
                        resultsList
                    case .noResults:
                        noResults
                            .padding(.horizontal, 16)
                    case .error(let message):
                        errorView(message)
                            .padding(.horizontal, 16)
                    case .idle:
                        EmptyView()
                    }

                    Color.clear.frame(height: 80)   // tab bar safe area
                }
            }
            .clipped()
        }
        .clipped()
        .transition(.opacity)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color.black.opacity(0.55)
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
    }

    // MARK: - States

    private var tooShortHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(L("promo_search_min_chars"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var skeletonRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { idx in
                SkeletonRow()
                if idx < 5 {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 0.5)
                        .padding(.leading, 76)
                        .padding(.trailing, 16)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { idx, item in
                FolderSearchSuggestionRow(item: item) {
                    onTapResult(item, idx)
                }
                if idx < viewModel.results.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 0.5)
                        .padding(.leading, 76)
                        .padding(.trailing, 16)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text(L("promo_search_no_results"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("\(L("promo_search_no_results_for")) \"\(viewModel.query)\"")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            if viewModel.storeFilter != nil {
                Button {
                    viewModel.setStoreFilter(nil)
                } label: {
                    Text(L("promo_search_clear_filter"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.orange.opacity(0.85))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button {
                viewModel.onQueryChange()
            } label: {
                Text(L("promo_search_retry"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Skeleton row

private struct SkeletonRow: View {
    @State private var pulse = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 10).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 3).frame(width: 60, height: 8)
                RoundedRectangle(cornerRadius: 3).frame(maxWidth: .infinity).frame(height: 12)
                RoundedRectangle(cornerRadius: 3).frame(width: 110, height: 9)
            }
            VStack(alignment: .trailing, spacing: 4) {
                RoundedRectangle(cornerRadius: 3).frame(width: 46, height: 12)
                RoundedRectangle(cornerRadius: 3).frame(width: 30, height: 9)
            }
            Circle().frame(width: 26, height: 26)
        }
        .foregroundStyle(.white.opacity(pulse ? 0.10 : 0.05))
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

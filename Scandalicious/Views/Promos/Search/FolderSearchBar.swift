//
//  FolderSearchBar.swift
//  Scandalicious
//
//  Sticky capsule search bar that floats above the Folders tab content.
//  Modern App-Store / Apple-Music feel: ultraThinMaterial, animated focus
//  border, animated Cancel button when focused.
//

import SwiftUI

struct FolderSearchBar: View {
    @ObservedObject var viewModel: PromoSearchViewModel
    @FocusState private var isFieldFocused: Bool
    let onTapFilter: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            pill
            if viewModel.isFocused {
                cancelButton
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.isFocused)
        .onChange(of: isFieldFocused) { _, newValue in
            // FocusState → ViewModel → phase. Only set false here when the
            // user actually loses focus (tapped Cancel or outside). Tap-to-focus
            // is the source of truth via .focused().
            viewModel.setFocused(newValue)
        }
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(viewModel.query.isEmpty ? 0.5 : 0.85))

            TextField("", text: $viewModel.query, prompt:
                Text(L("promo_search_placeholder"))
                    .foregroundStyle(.white.opacity(0.45))
            )
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .tint(.white)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            .focused($isFieldFocused)
            .onChange(of: viewModel.query) { _, _ in
                viewModel.onQueryChange()
            }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clearQuery()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            filterButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    viewModel.isFocused
                        ? Color.blue.opacity(0.6)
                        : Color.white.opacity(0.10),
                    lineWidth: viewModel.isFocused ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .animation(.spring(response: 0.3), value: viewModel.isFocused)
        .animation(.easeInOut(duration: 0.15), value: viewModel.query.isEmpty)
        .sensoryFeedback(.selection, trigger: viewModel.isFocused)
    }

    private var filterButton: some View {
        Button(action: onTapFilter) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                if viewModel.storeFilter != nil {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color(white: 0.05), lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L("promo_search_filter_store")))
    }

    // MARK: - Cancel

    private var cancelButton: some View {
        Button {
            viewModel.clearQuery()
            isFieldFocused = false
        } label: {
            Text(L("cancel"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

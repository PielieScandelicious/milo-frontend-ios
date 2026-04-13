//
//  PromoFolderBrowserView.swift
//  Scandalicious
//
//  Store-grouped promo folder browser with cover cards.
//

import SwiftUI

// MARK: - Folder Home View (full-tab wrapper)

struct FolderHomeView: View {
    @ObservedObject var viewModel: PromoFoldersViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var scrollOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var showProfile = false
    @State private var showWalletPassCreator = false
    @State private var showGroceryList = false
    @ObservedObject private var groceryStore = GroceryListStore.shared

    // Deep blue gradient — distinct from Deals tab's emerald green
    private let headerBlue = Color(red: 0.04, green: 0.12, blue: 0.28)

    var body: some View {
        ZStack(alignment: .top) {
            Color(white: 0.05).ignoresSafeArea()

            // Deep blue gradient header
            GeometryReader { geometry in
                LinearGradient(
                    stops: [
                        .init(color: headerBlue, location: 0.0),
                        .init(color: headerBlue.opacity(0.7), location: 0.25),
                        .init(color: headerBlue.opacity(0.3), location: 0.5),
                        .init(color: Color.clear, location: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.45 + geometry.safeAreaInsets.top)
                .frame(maxWidth: .infinity)
                .offset(y: -geometry.safeAreaInsets.top)
                .opacity(headerGradientOpacity)
                .animation(.linear(duration: 0.1), value: scrollOffset)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero header
                        heroHeader
                            .padding(.horizontal, 16)

                        // Folder browser content
                        PromoFolderBrowserView(viewModel: viewModel)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                    .frame(width: geo.size.width)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: FolderScrollOffsetKey.self,
                                    value: -proxy.frame(in: .named("folderScroll")).origin.y
                                )
                        }
                    )
                }
            }
            .coordinateSpace(name: "folderScroll")
            .onPreferenceChange(FolderScrollOffsetKey.self) { value in
                scrollOffset = max(0, value)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                GroceryListToolbarButton(count: groceryStore.activeItemCount) {
                    showGroceryList = true
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showProfile = true
                    } label: {
                        Label("Profile", systemImage: "gearshape")
                    }
                    Button {
                        showWalletPassCreator = true
                    } label: {
                        Label("Wallet Pass Creator", systemImage: "wallet.pass")
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .environmentObject(authManager)
                    .environmentObject(SubscriptionManager.shared)
            }
        }
        .sheet(isPresented: $showWalletPassCreator) {
            WalletPassCreatorView()
        }
        .sheet(isPresented: $showGroceryList) {
            GroceryListSheet()
        }
        .opacity(contentOpacity)
        .refreshable {
            await viewModel.loadFolders(forceRefresh: true)
        }
        .tint(.white.opacity(0.6))
        .onAppear {
            withAnimation(.smooth(duration: 0.5)) {
                contentOpacity = 1.0
            }
        }
        .task {
            await viewModel.loadFolders()
        }
    }

    // MARK: - Hero Header

    @ViewBuilder
    private var heroHeader: some View {
        if case .success(let folders) = viewModel.state, !folders.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week's Folders")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Browse the latest deals from your favourite stores")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineSpacing(2)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Header fade

    private var headerGradientOpacity: Double {
        let fadeEnd: CGFloat = 200
        if scrollOffset <= 0 { return 1.0 }
        if scrollOffset >= fadeEnd { return 0.0 }
        return Double(1.0 - (scrollOffset / fadeEnd))
    }
}

private struct FolderScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Folder Browser Content

struct PromoFolderBrowserView: View {
    @ObservedObject var viewModel: PromoFoldersViewModel

    var body: some View {
        switch viewModel.state {
        case .idle, .loading:
            folderSkeletonView
        case .success(let folders):
            if folders.isEmpty {
                emptyFoldersView
            } else {
                folderContent
            }
        case .error(let message):
            folderErrorView(message: message)
        }
    }

    // MARK: - Content

    private var folderContent: some View {
        VStack(spacing: 28) {
            // Store filter chips
            folderStoreFilterBar

            // Store sections with dividers
            let groups = viewModel.foldersByStore
            ForEach(Array(groups.enumerated()), id: \.element.storeId) { index, group in
                storeFolderSection(
                    storeId: group.storeId,
                    displayName: group.displayName,
                    folders: group.folders
                )

                // Subtle divider between sections
                if index < groups.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                        .padding(.horizontal, 32)
                }
            }
        }
    }

    // MARK: - Store Filter Bar

    private var folderStoreFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                folderFilterChip(
                    label: "All",
                    count: viewModel.totalFolderCount,
                    isSelected: viewModel.selectedStoreFilter == nil,
                    storeName: nil
                ) {
                    withAnimation(.smooth(duration: 0.25)) {
                        viewModel.selectedStoreFilter = nil
                    }
                }

                // Per-store chips
                ForEach(viewModel.storeFilterOptions, id: \.storeId) { option in
                    let store = GroceryStore.fromCanonical(option.storeId)
                    folderFilterChip(
                        label: option.displayName,
                        count: option.count,
                        isSelected: viewModel.selectedStoreFilter == option.storeId,
                        storeName: option.storeId
                    ) {
                        withAnimation(.smooth(duration: 0.25)) {
                            viewModel.selectedStoreFilter = option.storeId
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func folderFilterChip(
        label: String,
        count: Int,
        isSelected: Bool,
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
                        ? folderBlue.opacity(0.25)
                        : Color.white.opacity(0.06)
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected
                        ? folderBlue.opacity(0.5)
                        : Color.white.opacity(0.08),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Store Section

    private func storeFolderSection(
        storeId: String,
        displayName: String,
        folders: [PromoFolder]
    ) -> some View {
        let storeColor = GroceryStore.fromCanonical(storeId)?.accentColor ?? folderBlue

        return VStack(alignment: .leading, spacing: 14) {
            // Store header
            HStack(spacing: 12) {
                StoreLogoView(storeName: storeId, height: 24)
                    .frame(width: 40, height: 40)
                    .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(storeColor.opacity(0.2), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    if let firstFolder = folders.first {
                        let display = firstFolder.validityDisplay
                        HStack(spacing: 4) {
                            if let icon = display.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(display.color)
                            }
                            Text(display.text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(display.color)
                        }
                    }
                }

                Spacer()

                if folders.count > 1 {
                    Text("\(folders.count) folders")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(storeColor.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(storeColor.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 16)

            // Folder cards — horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(folders) { folder in
                        NavigationLink(destination: PromoFolderPageViewer(folder: folder)) {
                            FolderCoverCard(folder: folder, storeId: storeId)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Empty State

    private var emptyFoldersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text("No folders available")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Text("Promo folders will appear here when they become available.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Error State

    private func folderErrorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.orange.opacity(0.6))

            Text("Couldn't load folders")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.loadFolders(forceRefresh: true) }
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(folderBlue))
            }
        }
        .padding(40)
    }

    // MARK: - Skeleton

    private var folderSkeletonView: some View {
        VStack(spacing: 24) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 100, height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 70, height: 10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<2, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.04))
                                    .frame(width: 150, height: 200)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
        .shimmer()
    }

    private let folderBlue = Color(red: 0.30, green: 0.55, blue: 0.95)
}

// MARK: - Folder Cover Card

struct FolderCoverCard: View {
    let folder: PromoFolder
    let storeId: String

    private let cardWidth: CGFloat = 160
    private let coverHeight: CGFloat = 210

    private var storeAccentColor: Color {
        GroceryStore.fromCanonical(storeId)?.accentColor ?? Color(red: 0.30, green: 0.55, blue: 0.95)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Cover image
            if let coverUrl = folder.coverImageUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: cardWidth, height: coverHeight)
                    case .failure:
                        folderPlaceholder
                    default:
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: cardWidth, height: coverHeight)
                            .overlay(
                                ProgressView()
                                    .tint(.white.opacity(0.3))
                            )
                    }
                }
            } else {
                folderPlaceholder
            }

            // Info bar
            HStack(spacing: 6) {
                Text(folder.folderName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(folder.pageCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color(white: 0.07))
        }
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(storeAccentColor.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }

    private var folderPlaceholder: some View {
        Rectangle()
            .fill(Color(white: 0.06))
            .frame(width: cardWidth, height: coverHeight)
            .overlay(
                Image(systemName: "newspaper")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.15))
            )
    }
}

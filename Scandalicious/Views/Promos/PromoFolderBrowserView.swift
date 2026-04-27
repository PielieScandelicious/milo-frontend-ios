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
    @StateObject private var searchVM = PromoSearchViewModel()
    @State private var scrollOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var showProfile = false
    @State private var showWalletPassCreator = false
    @State private var showSearchFilter = false
    @State private var selectedSearchResult: PromoStoreItem?
    /// Bumped every time the search bar is focused; used as the overlay's
    /// `.id()` so each open creates a fresh ScrollView (and gesture recognizer)
    /// instance. Prevents stuck horizontal-pan state from carrying over between
    /// open/Cancel cycles.
    @State private var searchOpenToken: Int = 0

    // Reserved height for the floating search pill (used as scroll-content top
    // padding so the pill doesn't overlap the hero header).
    private let searchPillSpace: CGFloat = 60

    // Stores currently surfaced by the API (per the audit: 11 retailers).
    private let searchableStores: [GroceryStore] = [
        .colruyt, .delhaize, .carrefour, .carrefourMarket,
        .lidl, .aldi, .albertHeijn, .okay, .spar, .jumbo, .intermarche,
    ]

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
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Reserve vertical space below the floating search pill
                            Color.clear.frame(height: searchPillSpace)

                            // Hero header
                            heroHeader
                                .padding(.horizontal, 16)

                            // Folder browser content
                            PromoFolderBrowserView(viewModel: viewModel, scrollProxy: scrollProxy)
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
            }
            .coordinateSpace(name: "folderScroll")
            .onPreferenceChange(FolderScrollOffsetKey.self) { value in
                scrollOffset = max(0, value)
            }
            .blur(radius: searchVM.isFocused ? 14 : 0)
            .scaleEffect(searchVM.isFocused ? 0.98 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: searchVM.isFocused)
            // While search is open, the underlying folder grid must not consume
            // any touches — otherwise its own scroll view + tabbar can react to
            // horizontal swipes that fell through the overlay.
            .allowsHitTesting(!searchVM.isFocused)

            // Focused search overlay (above blurred grid, below sticky pill)
            if searchVM.isFocused {
                FolderSearchOverlay(
                    viewModel: searchVM,
                    topInset: searchPillSpace,
                    onPickQuery: { searchVM.submitSuggestedQuery($0) },
                    onTapResult: { item, idx in
                        searchVM.recordResultTap(item, position: idx)
                        selectedSearchResult = item
                    }
                )
                .id(searchOpenToken)
                .transition(.opacity)
                .zIndex(1)
            }

            // Sticky top bar (search pill + gear menu) — pinned at safe-area top.
            HStack(spacing: 10) {
                FolderSearchBar(viewModel: searchVM, onTapFilter: { showSearchFilter = true })
                if !searchVM.isFocused {
                    gearMenu
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .zIndex(2)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: searchVM.isFocused)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: searchVM.isFocused) { _, isFocused in
            // Force a fresh overlay instance on every open so any stuck
            // gesture-recognizer state from the previous session is discarded.
            if isFocused { searchOpenToken &+= 1 }
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
        .sheet(isPresented: $showSearchFilter) {
            FolderSearchFilterSheet(
                selection: Binding(
                    get: { searchVM.storeFilter },
                    set: { searchVM.setStoreFilter($0) }
                ),
                availableStores: searchableStores
            )
        }
        .sheet(item: $selectedSearchResult) { item in
            PromoProductDetailSheet(
                gridItem: PromoGridItem(
                    id: item.itemKey ?? item.id,
                    item: item,
                    storeName: item.storeName ?? "unknown"
                )
            )
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .opacity(contentOpacity)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("This week's folders")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                .white.opacity(0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Your weekly deal hunt starts here.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .tracking(0.2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Gear menu (floats next to the search pill)

    @ViewBuilder
    private var gearMenu: some View {
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle().stroke(.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
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
    @ObservedObject private var favoritesManager = FavoriteStoresManager.shared
    var scrollProxy: ScrollViewProxy? = nil
    @State private var expandedStoreId: String? = nil
    @State private var dayToken: Date = Calendar.current.startOfDay(for: Date())
    @State private var showFavoritesPicker = false

    var body: some View {
        content
            .id(dayToken)
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                dayToken = Calendar.current.startOfDay(for: Date())
            }
    }

    @ViewBuilder
    private var content: some View {
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
        let partition = viewModel.foldersByStorePartitioned(favorites: favoritesManager.favorites)
        let favs = partition.favorites
        let others = partition.others

        return LazyVStack(spacing: 16) {
            if favs.isEmpty {
                HStack {
                    favoritesCTACard
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            } else {
                favoritesSectionHeader
                    .padding(.horizontal, 16)
                grid(for: favs)
            }

            if !others.isEmpty {
                allStoresSectionHeader
                    .padding(.horizontal, 16)
                    .padding(.top, favs.isEmpty ? 4 : 6)
                grid(for: others)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: favoritesManager.favorites)
        .sheet(isPresented: $showFavoritesPicker) {
            FavoriteStoresPickerSheet(favoritesManager: favoritesManager)
        }
    }

    // MARK: - Grid Builder

    private func grid(
        for groups: [(storeId: String, displayName: String, folders: [PromoFolder])]
    ) -> some View {
        let rows = stride(from: 0, to: groups.count, by: 2).map {
            Array(groups[$0..<min($0 + 2, groups.count)])
        }

        return LazyVStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(row, id: \.storeId) { group in
                        Group {
                            if group.folders.count == 1, let folder = group.folders.first {
                                NavigationLink {
                                    PromoFolderPageViewer(folder: folder)
                                } label: {
                                    StoreFolderGridCard(
                                        storeId: group.storeId,
                                        displayName: group.displayName,
                                        folders: group.folders,
                                        isSelected: false
                                    )
                                }
                                .buttonStyle(PressableCardStyle())
                            } else {
                                Button {
                                    let willExpand = expandedStoreId != group.storeId
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                        expandedStoreId = willExpand ? group.storeId : nil
                                    }
                                    if willExpand, let scrollProxy {
                                        // Defer so the ExpandedFolderLane is inserted before we scroll to it.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                                                scrollProxy.scrollTo(group.storeId, anchor: .top)
                                            }
                                        }
                                    }
                                } label: {
                                    StoreFolderGridCard(
                                        storeId: group.storeId,
                                        displayName: group.displayName,
                                        folders: group.folders,
                                        isSelected: expandedStoreId == group.storeId
                                    )
                                }
                                .buttonStyle(PressableCardStyle())
                            }
                        }
                        .id(group.storeId)
                        .frame(maxWidth: .infinity)
                    }
                    if row.count == 1 {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }

                if let expandedId = expandedStoreId,
                   let expandedGroup = row.first(where: { $0.storeId == expandedId }) {
                    ExpandedFolderLane(
                        folders: expandedGroup.folders,
                        storeId: expandedGroup.storeId,
                        displayName: expandedGroup.displayName
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity
                    ))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Section Headers

    private var favoritesSectionHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.95, green: 0.80, blue: 0.30))
            Text(L("folders_your_favorites").uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.75))
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
            editFavoritesPill
        }
    }

    private var allStoresSectionHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(L("folders_all_stores").uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    private var editFavoritesPill: some View {
        Button {
            showFavoritesPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .bold))
                Text(L("folders_edit_favorites"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Favorites CTA

    private var favoritesCTACard: some View {
        Button {
            showFavoritesPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(L("folders_pick_favorites_cta_title"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.04, green: 0.12, blue: 0.28).opacity(0.70), location: 0),
                                .init(color: Color(red: 0.04, green: 0.12, blue: 0.28).opacity(0.30), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableCardStyle())
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

    @ObservedObject private var readManager = ReadFoldersManager.shared

    private let cardWidth: CGFloat = 160
    private let coverHeight: CGFloat = 210

    private var storeAccentColor: Color {
        GroceryStore.fromCanonical(storeId)?.accentColor ?? Color(red: 0.30, green: 0.55, blue: 0.95)
    }

    private var isRead: Bool {
        readManager.contains(folder.folderId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Cover image
            Group {
                if let coverUrl = folder.coverImageUrl, let url = URL(string: coverUrl) {
                    RemoteImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: cardWidth, height: coverHeight)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: cardWidth, height: coverHeight)
                            .overlay(
                                ProgressView()
                                    .tint(.white.opacity(0.3))
                            )
                    }
                } else {
                    folderPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Read-state dot lane (centered under the cover)
            ReadStateDot(isRead: isRead)
                .frame(width: cardWidth, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 2)

            // Info bar
            HStack(spacing: 6) {
                ValidityChip(validityEnd: folder.validityEnd)

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
            .padding(.horizontal, 2)
            .padding(.top, 6)
        }
        .frame(width: cardWidth)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
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

// MARK: - Read State Dot

struct ReadStateDot: View {
    let isRead: Bool

    static let size: CGFloat = 10
    static let inset: CGFloat = 8

    private static let readGreen  = Color(red: 0.20, green: 0.76, blue: 0.42)
    private static let unreadRed  = Color(red: 0.92, green: 0.26, blue: 0.30)

    private var fill: Color {
        isRead ? Self.readGreen : Self.unreadRed
    }

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: Self.size, height: Self.size)
            .overlay {
                if isRead {
                    Image(systemName: "checkmark")
                        .font(.system(size: Self.size * 0.65, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

// MARK: - Store Folder Grid Card

private struct StoreFolderGridCard: View {
    let storeId: String
    let displayName: String
    let folders: [PromoFolder]
    let isSelected: Bool

    @ObservedObject private var readManager = ReadFoldersManager.shared

    private var accent: Color {
        GroceryStore.fromCanonical(storeId)?.accentColor
            ?? Color(red: 0.30, green: 0.55, blue: 0.95)
    }

    private var allFoldersRead: Bool {
        !folders.isEmpty && folders.allSatisfy { readManager.contains($0.folderId) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StackedCoversView(folders: folders, accent: accent)
                .frame(maxWidth: .infinity)
                .aspectRatio(0.88, contentMode: .fit)

            // Aggregate read-state dot — green when every folder in this store has been opened
            ReadStateDot(isRead: allFoldersRead)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .center, spacing: 10) {
                StoreLogoView(storeName: storeId, height: 22)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(Color.white)
                    )
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 4) {
                        Image(systemName: folders.count > 1 ? "square.stack.fill" : "doc.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text(folderCountText)
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.55))

                    if folders.count == 1, let only = folders.first {
                        ValidityChip(validityEnd: only.validityEnd, compact: true)
                            .opacity(0.85)
                    }

                    Spacer(minLength: 0)
                }
                .frame(height: 54, alignment: .topLeading)

                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .scaleEffect(isSelected ? 1.015 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isSelected)
    }

    private var folderCountText: String {
        if folders.count == 1, let only = folders.first {
            return only.pageCount == 1 ? "1 page" : "\(only.pageCount) pages"
        }
        return "\(folders.count) folders"
    }
}

private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Stacked Covers View

private struct StackedCoversView: View {
    let folders: [PromoFolder]
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardW = w * 0.78
            let cardH = h * 0.96

            ZStack {
                // Render back-most first, front-most last.
                ForEach(Array(backLayers.enumerated()), id: \.offset) { index, folder in
                    let depth = backLayers.count - index
                    coverCard(folder: folder, width: cardW, height: cardH)
                        .rotationEffect(.degrees(rotation(for: depth, total: backLayers.count)))
                        .offset(offset(for: depth, total: backLayers.count))
                        .opacity(1.0 - Double(depth) * 0.15)
                        .scaleEffect(1.0 - CGFloat(depth) * 0.03)
                }

                if let front = folders.first {
                    coverCard(folder: front, width: cardW, height: cardH)
                        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
                }
            }
            .frame(width: w, height: h)
        }
    }

    // Up to 2 back layers (3rd folder and beyond are represented by the 2nd back card).
    private var backLayers: [PromoFolder] {
        guard folders.count > 1 else { return [] }
        return Array(folders.dropFirst().prefix(2))
    }

    private func rotation(for depth: Int, total: Int) -> Double {
        // depth 1 = closest behind, depth 2 = further behind.
        let sign: Double = depth == 1 ? 1 : -1
        return sign * Double(depth) * 5.5
    }

    private func offset(for depth: Int, total: Int) -> CGSize {
        let sign: CGFloat = depth == 1 ? 1 : -1
        return CGSize(width: sign * CGFloat(depth) * 8, height: CGFloat(depth) * 4)
    }

    @ViewBuilder
    private func coverCard(folder: PromoFolder, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let urlString = folder.coverImageUrl, let url = URL(string: urlString) {
                RemoteImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(white: 0.12)
                        .overlay(ProgressView().tint(.white.opacity(0.3)))
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        Color(white: 0.10)
            .overlay(
                Image(systemName: "newspaper")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white.opacity(0.2))
            )
    }
}

// MARK: - Expanded Folder Lane

private struct ExpandedFolderLane: View {
    let folders: [PromoFolder]
    let storeId: String
    let displayName: String

    @State private var scrollProgress: CGFloat = 0
    @State private var contentOverflows: Bool = false
    @State private var swipeHintPhase: CGFloat = 0

    private var accent: Color {
        GroceryStore.fromCanonical(storeId)?.accentColor
            ?? Color(red: 0.30, green: 0.55, blue: 0.95)
    }

    private var sortedFolders: [PromoFolder] {
        folders.sorted {
            $0.folderName.localizedCaseInsensitiveCompare($1.folderName) == .orderedAscending
        }
    }

    // Trailing fade strength eases out as the user scrolls to the end, so the
    // cue disappears once it's no longer useful.
    private var trailingFadeStrength: CGFloat {
        guard contentOverflows else { return 0 }
        let remaining = max(0, 1 - scrollProgress)
        return min(1, remaining * 2.2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 10)

            lane

            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.10), location: 0.5),
                    .init(color: .white.opacity(0), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
        .padding(.bottom, 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                swipeHintPhase = 1
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(accent)
                .frame(width: 3, height: 14)

            Text(displayName.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 8)

            if contentOverflows {
                swipeHint
            }
        }
    }

    // Two chevrons gently drifting right — the eye catches the motion and
    // reads the lane as horizontally scrollable without adding chrome.
    private var swipeHint: some View {
        HStack(spacing: 3) {
            Text("swipe")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))

            ZStack {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25 + 0.35 * (1 - swipeHintPhase)))
                    .offset(x: -4 + 6 * swipeHintPhase)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25 + 0.35 * swipeHintPhase))
                    .offset(x: 2 + 6 * swipeHintPhase)
            }
            .frame(width: 18, height: 10)
            .clipped()
        }
        .opacity(trailingFadeStrength)
        .animation(.easeOut(duration: 0.2), value: trailingFadeStrength)
    }

    private var lane: some View {
        GeometryReader { outer in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortedFolders) { folder in
                        NavigationLink(destination: PromoFolderPageViewer(folder: folder)) {
                            FolderCoverCard(folder: folder, storeId: storeId)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    GeometryReader { inner in
                        Color.clear.preference(
                            key: LaneGeometryKey.self,
                            value: LaneGeometry(
                                offset: -inner.frame(in: .named("expandedLane")).origin.x,
                                contentWidth: inner.size.width
                            )
                        )
                    }
                )
            }
            .coordinateSpace(name: "expandedLane")
            .onPreferenceChange(LaneGeometryKey.self) { geo in
                let viewport = outer.size.width
                let overflow = max(0, geo.contentWidth - viewport)
                contentOverflows = overflow > 1
                scrollProgress = overflow > 0
                    ? min(1, max(0, geo.offset / overflow))
                    : 1
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 1 - 0.12 * trailingFadeStrength),
                        .init(color: .black.opacity(1 - Double(trailingFadeStrength)), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .frame(height: 234)
    }
}

private struct LaneGeometry: Equatable {
    var offset: CGFloat
    var contentWidth: CGFloat
}

private struct LaneGeometryKey: PreferenceKey {
    static var defaultValue = LaneGeometry(offset: 0, contentWidth: 0)
    static func reduce(value: inout LaneGeometry, nextValue: () -> LaneGeometry) {
        value = nextValue()
    }
}

// MARK: - Favorite Stores Picker Sheet

private struct FavoriteStoresPickerSheet: View {
    @ObservedObject var favoritesManager: FavoriteStoresManager
    @Environment(\.dismiss) private var dismiss

    private let headerBlue = Color(red: 0.04, green: 0.12, blue: 0.28)
    private let accentBlue = Color(red: 0.30, green: 0.55, blue: 0.95)
    private let accentDeep = Color(red: 0.10, green: 0.25, blue: 0.55)

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var allStores: [GroceryStore] { GroceryStore.promoSupported }
    private var allStoreIds: [String] { allStores.map { $0.canonicalName } }
    private var allSelected: Bool { favoritesManager.favorites.isSuperset(of: allStoreIds) }
    private var selectedCount: Int {
        favoritesManager.favorites.intersection(allStoreIds).count
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(white: 0.05).ignoresSafeArea()

            // Deep blue gradient — echoes the folder tab's header so the
            // sheet reads as an extension of the same surface.
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: headerBlue, location: 0),
                        .init(color: headerBlue.opacity(0.45), location: 0.4),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280 + geo.safeAreaInsets.top)
                .offset(y: -geo.safeAreaInsets.top)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroHeader
                    controlsBar
                    storeGrid
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)  // clears the top-right close button row
                .padding(.bottom, 140) // reserve space under sticky footer
            }

            stickyFooter
        }
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.top, 14)
                .padding(.trailing, 16)
        }
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: favoritesManager.favorites)
    }

    // MARK: - Hero

    private var heroHeader: some View {
        Text(L("folders_favorites_sheet_title"))
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .tracking(-0.6)
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: 10) {
            // Live count pill
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentBlue)
                Text("\(selectedCount) / \(allStores.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedCount)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(accentBlue.opacity(0.15)))
            .overlay(Capsule().stroke(accentBlue.opacity(0.35), lineWidth: 0.75))

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if allSelected {
                        favoritesManager.clear()
                    } else {
                        favoritesManager.setAll(allStoreIds)
                    }
                }
            } label: {
                Text(allSelected ? L("deselect_all") : L("select_all"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.08)))
                    .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Grid

    private var storeGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(allStores) { store in
                FavoriteStoreChip(
                    store: store,
                    isSelected: favoritesManager.contains(store.canonicalName),
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            favoritesManager.toggle(store.canonicalName)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Sticky Footer

    private var stickyFooter: some View {
        VStack(spacing: 0) {
            Spacer()

            // Fade gradient so the scrolling grid softens into the footer
            LinearGradient(
                colors: [Color(white: 0.05).opacity(0), Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            doneButton
                .padding(.horizontal, 16)
                .padding(.bottom, 44)  // sits well above the home indicator
                .background(Color(white: 0.05))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text(L("done"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [accentDeep, headerBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: accentDeep.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white.opacity(0.10)))
                .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Favorite Store Chip

private struct FavoriteStoreChip: View {
    let store: GroceryStore
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(store.logoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 60, maxHeight: 30)
                    .frame(height: 30)
                    .opacity(isSelected ? 1.0 : 0.7)

                Text(store.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? store.accentColor.opacity(0.22)
                          : Color.white.opacity(0.04))
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
                        Circle()
                            .fill(store.accentColor)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color(white: 0.05), lineWidth: 2)
                    )
                    .offset(x: 7, y: -7)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(color: isSelected ? store.accentColor.opacity(0.30) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

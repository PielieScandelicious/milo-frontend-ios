//
//  PromoFolderPageViewer.swift
//  Scandalicious
//
//  Full-screen promo folder page viewer with swipe-to-flip, pinch-to-zoom,
//  and interactive hotspot overlays for adding items to the grocery list.
//

import SwiftUI
import Combine

struct PromoFolderPageViewer: View {
    let folder: PromoFolder
    let initialPage: Int
    let highlightItemId: String?
    @State private var currentPage: Int
    @State private var selectedHotspot: PromoFolderHotspot?
    @State private var pushedFolderDestination: FolderDestination?
    @ObservedObject private var groceryStore = GroceryListStore.shared
    @EnvironmentObject private var foldersViewModel: PromoFoldersViewModel
    @Environment(\.dismiss) private var dismiss

    struct FolderDestination: Hashable {
        let folderId: String
        let pageIndex: Int
        let highlightItemId: String?
    }

    init(folder: PromoFolder, initialPage: Int = 0, highlightItemId: String? = nil) {
        self.folder = folder
        self.initialPage = initialPage
        self.highlightItemId = highlightItemId
        self._currentPage = State(initialValue: initialPage)
    }

    private var storeAccentColor: Color {
        GroceryStore.fromCanonical(folder.storeId)?.accentColor ?? Color(red: 0.20, green: 0.85, blue: 0.50)
    }

    /// Hotspot count for the current page
    private var currentPageHotspotCount: Int {
        guard currentPage < folder.pages.count else { return 0 }
        return folder.pages[currentPage].hotspots.count
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Page viewer
            TabView(selection: $currentPage) {
                ForEach(Array(folder.pages.enumerated()), id: \.element.id) { index, page in
                    ZoomablePageView(
                        imageUrl: page.imageUrl,
                        hotspots: page.hotspots,
                        storeAccentColor: storeAccentColor,
                        storeName: folder.storeId,
                        folderValidityEnd: folder.validityEnd,
                        groceryStore: groceryStore,
                        highlightItemId: index == initialPage ? highlightItemId : nil,
                        isActive: index == currentPage,
                        onInfoTap: { selectedHotspot = $0 }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator overlay
            VStack {
                Spacer()

                pageIndicator
                    .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        StoreLogoView(storeName: folder.storeId, height: 16)
                            .frame(width: 24, height: 24)
                        Text(folder.storeDisplayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    ValidityChip(validityEnd: folder.validityEnd)
                }
            }

        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .sheet(item: $selectedHotspot) { hotspot in
            PromoProductDetailSheet(
                gridItem: PromoGridItem(
                    id: hotspot.itemId,
                    item: hotspot.toPromoStoreItem(),
                    storeName: folder.storeId
                ),
                onOpenInFolder: { targetFolder, pageIndex, itemId in
                    // Skip no-op taps when the user is already exactly on the
                    // target page of the current folder — nothing to animate.
                    if targetFolder.folderId == folder.folderId && pageIndex == currentPage {
                        return
                    }
                    // Otherwise push a viewer pinned to the target promo, so
                    // the contour-trace spotlight runs on arrival. Using a
                    // push for same-folder jumps too means "back" returns the
                    // user to their previous page cleanly.
                    pushedFolderDestination = FolderDestination(
                        folderId: targetFolder.folderId,
                        pageIndex: pageIndex,
                        highlightItemId: itemId
                    )
                },
                originatingItemKey: hotspot.itemId
            )
            .environmentObject(foldersViewModel)
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $pushedFolderDestination) { dest in
            if case .success(let folders) = foldersViewModel.state,
               let targetFolder = folders.first(where: { $0.folderId == dest.folderId }) {
                PromoFolderPageViewer(
                    folder: targetFolder,
                    initialPage: dest.pageIndex,
                    highlightItemId: dest.highlightItemId
                )
            }
        }
        .task(id: currentPage) {
            prefetchImages(around: currentPage)
            await prefetchSimilarPromos(forPage: currentPage)
        }
    }

    /// Warm the shared image cache for the visible page and its neighbors:
    /// full page images (so fast-swipe lands on an already-decoded image) and
    /// hotspot hero crops (so tapping a hotspot skips the detail-sheet spinner).
    /// Window is biased forward — one page behind, two ahead — because swipes
    /// usually continue in the same direction.
    private func prefetchImages(around pageIndex: Int) {
        let lower = max(0, pageIndex - 1)
        let upper = min(folder.pages.count - 1, pageIndex + 2)
        guard lower <= upper else { return }
        for index in lower...upper {
            ImagePrefetcher.shared.prefetch(urlString: folder.pages[index].imageUrl)
            for hotspot in folder.pages[index].hotspots {
                ImagePrefetcher.shared.prefetch(urlString: hotspot.heroUrl ?? hotspot.imageUrl)
            }
        }
    }

    /// Prefetch `/promos/{id}/similar` for every hotspot on the visible page so
    /// the detail sheet's "Similar deals" carousel skips the shimmer on tap.
    /// The 500ms debounce matches `.task(id:)`'s cancellation model: rapid page
    /// swipes cancel the sleep before any personalized API calls are issued.
    private func prefetchSimilarPromos(forPage pageIndex: Int) async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled, pageIndex < folder.pages.count else { return }
        for hotspot in folder.pages[pageIndex].hotspots {
            SimilarPromosCache.shared.prefetch(promoId: hotspot.itemId, limit: 10)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            Text("\(currentPage + 1)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("/")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            Text("\(folder.pageCount)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            if currentPageHotspotCount > 0 {
                Text("·")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))

                HStack(spacing: 3) {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(currentPageHotspotCount)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

// MARK: - Zoomable Page View

/// A single folder page with pinch-to-zoom, double-tap-to-zoom,
/// and interactive hotspot tap detection for grocery list integration.
struct ZoomablePageView: View {
    let imageUrl: String
    let hotspots: [PromoFolderHotspot]
    let storeAccentColor: Color
    let storeName: String
    let folderValidityEnd: String
    let groceryStore: GroceryListStore
    var highlightItemId: String? = nil
    let isActive: Bool
    let onInfoTap: (PromoFolderHotspot) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZoomableImageContainer(
                imageUrl: imageUrl,
                containerSize: geometry.size,
                hotspots: hotspots,
                storeAccentColor: UIColor(storeAccentColor),
                storeName: storeName,
                folderValidityEnd: folderValidityEnd,
                groceryStore: groceryStore,
                highlightItemId: highlightItemId,
                isActive: isActive,
                onInfoTap: onInfoTap
            )
        }
    }
}

// MARK: - UIKit Zoomable Image Container

/// Wraps a UIScrollView for proper pinch-to-zoom with image centering
/// and interactive hotspot overlay support.
struct ZoomableImageContainer: UIViewRepresentable {
    let imageUrl: String
    let containerSize: CGSize
    let hotspots: [PromoFolderHotspot]
    let storeAccentColor: UIColor
    let storeName: String
    let folderValidityEnd: String
    let groceryStore: GroceryListStore
    var highlightItemId: String? = nil
    let isActive: Bool
    let onInfoTap: (PromoFolderHotspot) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.tag = 100
        scrollView.addSubview(imageView)

        // Single-tap for hotspot detection. No double-tap recognizer, so this
        // fires immediately instead of waiting ~300ms for iOS's double-tap
        // window to time out — pinch-to-zoom via UIScrollView still works.
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(singleTap)

        // Loading indicator
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.startAnimating()
        spinner.tag = 200
        scrollView.addSubview(spinner)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.hotspots = hotspots
        context.coordinator.storeAccentColor = storeAccentColor
        context.coordinator.storeName = storeName
        context.coordinator.folderValidityEnd = folderValidityEnd
        context.coordinator.groceryStore = groceryStore
        context.coordinator.highlightItemId = highlightItemId
        context.coordinator.onInfoTap = onInfoTap
        context.coordinator.observeGroceryStore()
        // Seed visibility before kicking off the image load so a page that's
        // already on-screen at create time runs the reveal as soon as the image
        // arrives. Off-screen pages stay quiet until they slide into view.
        if isActive {
            context.coordinator.pageBecameVisible()
        }
        context.coordinator.loadImage(url: imageUrl, containerSize: containerSize)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if let imageView = scrollView.viewWithTag(100) as? UIImageView {
            imageView.frame = CGRect(origin: .zero, size: containerSize)
        }
        if let spinner = scrollView.viewWithTag(200) as? UIActivityIndicatorView {
            spinner.center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        }
        // Visibility transitions drive the reveal animation — TabView pre-renders
        // adjacent pages, so triggering on image load fires off-screen and never
        // re-fires on swipe-back. Routing through visibility solves both.
        if isActive {
            context.coordinator.pageBecameVisible()
        } else {
            context.coordinator.pageBecameHidden()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var hotspots: [PromoFolderHotspot] = []
        var storeAccentColor: UIColor = .systemGreen
        var storeName: String = ""
        var folderValidityEnd: String = ""
        var groceryStore: GroceryListStore?
        var highlightItemId: String?
        var onInfoTap: ((PromoFolderHotspot) -> Void)?
        private var hotspotDots: [UIView] = []
        private var groceryCancellable: AnyCancellable?
        private var didRunSpotlight = false

        // Reveal-animation state. The reveal fires the first time the page is
        // both visible AND has its image loaded, then never again — swiping
        // back to a previously-seen page is silent. `revealLayers` and
        // `revealCleanupItems` are tracked so a swipe-away mid-animation can
        // tear down cleanly instead of leaving stale layers behind.
        private var imageLoaded = false
        private var isPageActive = false
        private var didRunReveal = false
        private var revealLayers: [CALayer] = []
        private var revealCleanupItems: [DispatchWorkItem] = []

        func observeGroceryStore() {
            groceryCancellable = groceryStore?.$items
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.refreshAllDotStates()
                }
        }

        /// Re-sync every hotspot's visual state against the grocery list.
        /// Keeps the folder viewer consistent with changes made in the detail
        /// sheet or the Grocery List tab.
        private func refreshAllDotStates() {
            guard let store = groceryStore else { return }
            for region in hotspotDots {
                guard let itemId = region.accessibilityIdentifier,
                      let hotspot = hotspots.first(where: { $0.itemId == itemId }) else { continue }
                let item = hotspot.toPromoStoreItem()
                let isAdded = store.contains(item: item, storeName: storeName)
                UIView.animate(withDuration: 0.2) {
                    if isAdded {
                        self.applyAddedStyle(to: region)
                    } else {
                        self.applyDefaultStyle(to: region)
                    }
                }
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter
        }

        // MARK: - Coordinate Mapping

        /// Compute the actual displayed image rect within the imageView,
        /// accounting for scaleAspectFit letterboxing.
        private func displayedImageRect(in imageView: UIImageView) -> CGRect {
            guard let image = imageView.image else { return imageView.bounds }
            let viewSize = imageView.bounds.size
            let imageSize = image.size

            guard viewSize.width > 0, viewSize.height > 0,
                  imageSize.width > 0, imageSize.height > 0 else {
                return imageView.bounds
            }

            let widthScale = viewSize.width / imageSize.width
            let heightScale = viewSize.height / imageSize.height
            let scale = min(widthScale, heightScale)

            let displayedWidth = imageSize.width * scale
            let displayedHeight = imageSize.height * scale
            let x = (viewSize.width - displayedWidth) / 2
            let y = (viewSize.height - displayedHeight) / 2

            return CGRect(x: x, y: y, width: displayedWidth, height: displayedHeight)
        }

        // MARK: - Gestures

        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard let imageView, !hotspots.isEmpty else { return }

            let tapPoint = gesture.location(in: imageView)
            let imageRect = displayedImageRect(in: imageView)

            guard imageRect.width > 0, imageRect.height > 0 else { return }

            // Normalize tap point to 0-1 relative to the actual displayed image
            let normalizedX = (tapPoint.x - imageRect.origin.x) / imageRect.width
            let normalizedY = (tapPoint.y - imageRect.origin.y) / imageRect.height

            // Reject taps outside the actual image area (in letterbox padding)
            guard normalizedX >= 0, normalizedX <= 1,
                  normalizedY >= 0, normalizedY <= 1 else { return }

            // Find the smallest hotspot containing the tap point (handles overlaps)
            var bestHotspot: PromoFolderHotspot?
            var bestArea: CGFloat = .greatestFiniteMagnitude

            for hotspot in hotspots {
                if normalizedX >= hotspot.tileBboxXMin && normalizedX <= hotspot.tileBboxXMax
                    && normalizedY >= hotspot.tileBboxYMin && normalizedY <= hotspot.tileBboxYMax
                {
                    let area = (hotspot.tileBboxXMax - hotspot.tileBboxXMin) * (hotspot.tileBboxYMax - hotspot.tileBboxYMin)
                    if area < bestArea {
                        bestArea = area
                        bestHotspot = hotspot
                    }
                }
            }

            guard let hotspot = bestHotspot else { return }

            // If the tap landed on the "+" add button, add to grocery list directly
            // and skip opening the detail sheet.
            if plusBadgeHitRect(for: hotspot, imageRect: imageRect).contains(tapPoint) {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                let item = hotspot.toPromoStoreItem()
                if let store = groceryStore, store.contains(item: item, storeName: storeName) {
                    // Tapping the button again removes the item and reverts styling.
                    store.removeByPromo(item: item, storeName: storeName)
                    revertDotForRemovedItem(hotspot: hotspot)
                } else {
                    groceryStore?.add(item: item, storeName: storeName, validityEndOverride: folderValidityEnd.isEmpty ? nil : folderValidityEnd)
                    showAddedFeedback(for: hotspot, in: imageView)
                }
                return
            }

            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()

            onInfoTap?(hotspot)
        }

        /// Hit-test rect (in imageView coords) for the "+" add button on a hotspot.
        /// Kept in sync with the badge geometry in `addHotspotDots`.
        private func plusBadgeHitRect(for hotspot: PromoFolderHotspot, imageRect: CGRect) -> CGRect {
            let rect = hotspot.tileRect(in: imageRect)
            let insetRect = rect.insetBy(dx: 2, dy: 2)
            let badgeSize = Self.badgeSize
            let badgeX = insetRect.maxX - badgeSize + 3
            let badgeY = insetRect.minY - 3
            // Expand hit target so a tight "+" circle is still forgiving to tap.
            return CGRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)
                .insetBy(dx: -8, dy: -8)
        }

        static let badgeSize: CGFloat = 20
        static let badgeIconSize: CGFloat = 11

        /// Premium blue used for the hotspot contour trace animation and the
        /// "+" badge — a refined, saturated azure that reads crisp on any
        /// folder background without feeling like a stock system blue.
        static let premiumBlueColor = UIColor(red: 0.10, green: 0.45, blue: 0.98, alpha: 1.0)

        /// Gold accent for coupon hotspots — differentiates scannable-at-till
        /// coupons from regular product promos at a glance.
        static let couponGoldColor = UIColor(red: 0.95, green: 0.70, blue: 0.15, alpha: 1.0)

        // MARK: - Visual Feedback

        private func showAddedFeedback(for hotspot: PromoFolderHotspot, in imageView: UIImageView) {
            let rect = hotspot.tileRect(in: displayedImageRect(in: imageView))
            let green = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)

            // Expanding ripple ring
            let ringSize: CGFloat = max(rect.width, rect.height)
            let ring = UIView(frame: CGRect(
                x: rect.midX - ringSize / 2,
                y: rect.midY - ringSize / 2,
                width: ringSize,
                height: ringSize
            ))
            ring.layer.cornerRadius = ringSize / 2
            ring.layer.borderColor = green.withAlphaComponent(0.9).cgColor
            ring.layer.borderWidth = 3
            ring.backgroundColor = .clear
            ring.alpha = 0.9
            ring.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            imageView.addSubview(ring)

            // Highlight rectangle
            let highlight = UIView(frame: rect)
            highlight.backgroundColor = green.withAlphaComponent(0.18)
            highlight.layer.borderColor = green.withAlphaComponent(0.5).cgColor
            highlight.layer.borderWidth = 1.5
            highlight.layer.cornerRadius = 8
            highlight.alpha = 0
            imageView.addSubview(highlight)

            // Checkmark icon
            let checkSize: CGFloat = 40
            let checkmark = UIImageView(image: UIImage(
                systemName: "checkmark.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: checkSize, weight: .bold)
            ))
            checkmark.tintColor = green
            checkmark.frame = CGRect(
                x: rect.midX - checkSize / 2,
                y: rect.midY - checkSize / 2,
                width: checkSize,
                height: checkSize
            )
            checkmark.layer.shadowColor = green.cgColor
            checkmark.layer.shadowOpacity = 0.6
            checkmark.layer.shadowRadius = 10
            checkmark.layer.shadowOffset = .zero
            checkmark.alpha = 0
            checkmark.transform = CGAffineTransform(scaleX: 0.2, y: 0.2).rotated(by: -.pi / 8)
            imageView.addSubview(checkmark)

            // Ripple expand-fade
            UIView.animate(withDuration: 0.55, delay: 0, options: [.curveEaseOut]) {
                ring.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
                ring.alpha = 0
            } completion: { _ in ring.removeFromSuperview() }

            // Highlight fade in, then out
            UIView.animate(withDuration: 0.18) {
                highlight.alpha = 1
            } completion: { _ in
                UIView.animate(withDuration: 0.35, delay: 0.45) {
                    highlight.alpha = 0
                } completion: { _ in highlight.removeFromSuperview() }
            }

            // Checkmark spring-in, then drift up and fade
            UIView.animate(withDuration: 0.32,
                           delay: 0.05,
                           usingSpringWithDamping: 0.55,
                           initialSpringVelocity: 1.2) {
                checkmark.alpha = 1
                checkmark.transform = .identity
            } completion: { _ in
                UIView.animate(withDuration: 0.45, delay: 0.35, options: [.curveEaseIn]) {
                    checkmark.alpha = 0
                    checkmark.transform = CGAffineTransform(translationX: 0, y: -24).scaledBy(x: 1.1, y: 1.1)
                } completion: { _ in checkmark.removeFromSuperview() }
            }

            updateDotForAddedItem(hotspot: hotspot, in: imageView)
        }

        private func showAlreadyAddedFeedback(for hotspot: PromoFolderHotspot, in imageView: UIImageView) {
            let rect = hotspot.tileRect(in: displayedImageRect(in: imageView))

            let label = UILabel()
            label.text = "Already added"
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            label.layer.cornerRadius = 10
            label.clipsToBounds = true
            label.sizeToFit()
            label.frame = CGRect(
                x: rect.midX - (label.frame.width + 16) / 2,
                y: rect.midY - 12,
                width: label.frame.width + 16,
                height: 24
            )
            label.alpha = 0
            imageView.addSubview(label)

            UIView.animate(withDuration: 0.15) {
                label.alpha = 1
            } completion: { _ in
                UIView.animate(withDuration: 0.2, delay: 0.8) {
                    label.alpha = 0
                } completion: { _ in
                    label.removeFromSuperview()
                }
            }
        }

        // MARK: - Hotspot Dot Indicators

        private func addHotspotDots(in imageView: UIImageView) {
            hotspotDots.forEach { $0.removeFromSuperview() }
            hotspotDots.removeAll()

            guard !hotspots.isEmpty else { return }

            let imageRect = displayedImageRect(in: imageView)
            guard imageRect.width > 0, imageRect.height > 0 else { return }

            for hotspot in hotspots {
                let rect = hotspot.tileRect(in: imageRect)
                let inset: CGFloat = 2
                let insetRect = rect.insetBy(dx: inset, dy: inset)

                // Invisible region container — holds the "+" badge and is the
                // anchor for the contour-trace reveal animation. The bbox
                // outline itself is never drawn as a static border; it only
                // ever appears as a premium blue stroke that traces the
                // perimeter once and disappears.
                let region = UIView(frame: insetRect)
                region.backgroundColor = .clear
                region.layer.cornerRadius = 8
                region.layer.borderColor = UIColor.clear.cgColor
                region.layer.borderWidth = 0
                region.accessibilityIdentifier = hotspot.itemId
                region.isUserInteractionEnabled = false

                // Coupons get a distinct gold accent (vs regular promos' blue) on
                // the "+" badge so users can spot "this tile is scannable at the
                // till" at a glance.
                let badgeColor: UIColor = hotspot.isCoupon ? Self.couponGoldColor : Self.premiumBlueColor
                let badgeIcon: String = hotspot.isCoupon ? "ticket.fill" : "plus"

                // Sits in the bbox's top-right corner with a small overhang.
                // The contour-trace path is shaped to start on the badge's
                // top-edge perimeter and end on its right-edge perimeter, so
                // the line emerges and retracts at the badge's edge — never
                // crossing into the icon.
                let badgeSize = Coordinator.badgeSize
                let badge = UIView(frame: CGRect(
                    x: insetRect.width - badgeSize + 3,
                    y: -3,
                    width: badgeSize,
                    height: badgeSize
                ))
                badge.backgroundColor = badgeColor
                badge.layer.cornerRadius = badgeSize / 2
                badge.layer.shadowColor = badgeColor.cgColor
                badge.layer.shadowOpacity = 0.35
                badge.layer.shadowOffset = CGSize(width: 0, height: 2)
                badge.layer.shadowRadius = 5
                badge.tag = 300

                let iconSize = Coordinator.badgeIconSize
                let iconView = UIImageView(image: UIImage(
                    systemName: badgeIcon,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
                ))
                iconView.tintColor = .white
                iconView.contentMode = .scaleAspectFit
                iconView.frame = CGRect(
                    x: (badgeSize - iconSize) / 2,
                    y: (badgeSize - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                iconView.tag = 301
                badge.addSubview(iconView)

                region.addSubview(badge)

                imageView.addSubview(region)
                hotspotDots.append(region)

                let promoItem = hotspot.toPromoStoreItem()
                if let store = groceryStore, store.contains(item: promoItem, storeName: storeName) {
                    applyAddedStyle(to: region)
                }
            }
        }

        // MARK: - Premium Hotspot Reveal

        /// Called when the page slides into view. Together with
        /// `pageBecameHidden`, drives the reveal animation off page visibility
        /// so it fires the first time the user actually sees the page —
        /// regardless of whether the image was already loaded behind the scenes.
        ///
        /// The reveal is gated behind a short "stably visible" delay: during
        /// fast swipes the page may flicker into view for just a few frames,
        /// and firing the reveal (plus its haptic) on each flyby feels noisy.
        /// Cancelling the pending work item in `pageBecameHidden` means a
        /// flyby leaves `didRunReveal` false, so the reveal still plays when
        /// the user actually lands on the page later.
        func pageBecameVisible() {
            guard !isPageActive else { return }
            isPageActive = true

            let item = DispatchWorkItem { [weak self] in
                self?.maybeRunReveal()
            }
            revealCleanupItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
        }

        /// Called when the page leaves view. Cancels any in-flight reveal (and
        /// the pending delayed trigger) so stale layers and late haptics don't
        /// outlive the swipe-away.
        func pageBecameHidden() {
            guard isPageActive else { return }
            isPageActive = false
            cancelInFlightReveal()
        }

        /// The reveal needs both prerequisites — the image must have arrived
        /// (so `addHotspotDots` has run and laid out the regions) and the page
        /// must be the visible one. Whichever trigger completes the conditions
        /// last wins. Once it's run, `didRunReveal` keeps subsequent revisits
        /// silent.
        private func maybeRunReveal() {
            guard !didRunReveal else { return }
            guard imageLoaded, isPageActive, highlightItemId == nil else { return }
            guard !hotspotDots.isEmpty else { return }
            didRunReveal = true
            animateHotspotReveal()
        }

        /// Tear down everything from a previous reveal — layers and any pending
        /// cleanup work items — so re-entry can't accumulate state.
        private func cancelInFlightReveal() {
            revealCleanupItems.forEach { $0.cancel() }
            revealCleanupItems.removeAll()
            revealLayers.forEach { $0.removeAllAnimations(); $0.removeFromSuperlayer() }
            revealLayers.removeAll()
        }

        /// On page reveal, a thick shiny blue arc traces the contour of every
        /// hotspot bbox simultaneously and retracts — leaving only the "+"
        /// badge as the persistent affordance.
        private func animateHotspotReveal() {
            guard !hotspotDots.isEmpty else { return }

            // Soft haptic to cue the reveal — light, not intrusive.
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            impact.impactOccurred(intensity: 0.4)

            for region in hotspotDots {
                traceContour(on: region, color: Self.premiumBlueColor)
            }
        }

        /// Draws the premium reveal as a comet sliding clockwise around the
        /// bbox: a thick bright head with a naturally tapering tail behind it.
        ///
        /// The taper is built from a stack of `CAShapeLayer`s that share the
        /// same head position (`strokeEnd`) but have different tail offsets
        /// (`strokeStart`). Shorter, wider segments sit on top; longer, thinner
        /// segments sit behind. Because all segments share the same leading
        /// edge, the eye reads the stack as one continuous stroke that's thick
        /// at the tip and fades to a point — a comet silhouette. An extra
        /// ice-white gleam caps the very head for the nucleus.
        private func traceContour(on region: UIView, color: UIColor) {
            let bounds = region.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }

            let path = Self.contourPath(in: bounds, cornerRadius: 8)

            // 0.8s total — slow enough to read as a deliberate reveal, fast
            // enough that a page with many hotspots doesn't feel like it's
            // stalling. headEndT splits the timeline: head sweeps 0→1 over
            // [0, headEndT], then holds at 1 while tails catch up over the
            // retract phase. Sharing this exact head animation across every
            // stack layer is what keeps the comet nucleus locked to the tip.
            let totalDuration: CFTimeInterval = 0.8
            let headEndT: Double = 0.82
            let now = CACurrentMediaTime()

            func makeHeadAnim() -> CAKeyframeAnimation {
                let head = CAKeyframeAnimation(keyPath: "strokeEnd")
                head.values = [0, 1, 1]
                head.keyTimes = [0, NSNumber(value: headEndT), 1]
                head.duration = totalDuration
                head.beginTime = now
                head.fillMode = .forwards
                head.isRemovedOnCompletion = false
                return head
            }

            // Per-layer tail: stays at 0 until head has pulled ahead by the
            // dashFraction, then mirrors the head's velocity (constant-length
            // segment), and finally catches up to 1 during the retract phase.
            func makeTailAnim(dashFraction D: Double) -> CAKeyframeAnimation {
                let tail = CAKeyframeAnimation(keyPath: "strokeStart")
                tail.values = [0, 0, 1 - D, 1]
                tail.keyTimes = [
                    0,
                    NSNumber(value: D * headEndT),
                    NSNumber(value: headEndT),
                    1
                ]
                tail.duration = totalDuration
                tail.beginTime = now
                tail.fillMode = .forwards
                tail.isRemovedOnCompletion = false
                return tail
            }

            // Comet segments — first entry is drawn first (furthest back, thin,
            // long tail), last entry is drawn last (on top, thick, short tip).
            // Opacity tapers too so the tail fades out softly.
            struct Segment {
                let lineWidth: CGFloat
                let dashFraction: Double
                let opacity: Float
                let shadowRadius: CGFloat
            }
            let segments: [Segment] = [
                .init(lineWidth: 1.2, dashFraction: 0.18, opacity: 0.40, shadowRadius: 3),
                .init(lineWidth: 2.0, dashFraction: 0.12, opacity: 0.62, shadowRadius: 5),
                .init(lineWidth: 3.0, dashFraction: 0.07, opacity: 0.85, shadowRadius: 7),
                .init(lineWidth: 4.2, dashFraction: 0.03, opacity: 1.00, shadowRadius: 10),
            ]

            var createdLayers: [CAShapeLayer] = []

            for seg in segments {
                let layer = CAShapeLayer()
                layer.frame = bounds
                layer.path = path
                layer.strokeColor = color.cgColor
                layer.fillColor = UIColor.clear.cgColor
                layer.lineWidth = seg.lineWidth
                layer.lineCap = .round
                layer.lineJoin = .round
                layer.strokeStart = 0
                layer.strokeEnd = 0
                layer.opacity = seg.opacity
                layer.shadowColor = color.cgColor
                layer.shadowOpacity = 0.85
                layer.shadowRadius = seg.shadowRadius
                layer.shadowOffset = .zero
                region.layer.addSublayer(layer)
                revealLayers.append(layer)
                createdLayers.append(layer)

                layer.add(makeHeadAnim(), forKey: "head")
                layer.add(makeTailAnim(dashFraction: seg.dashFraction), forKey: "tail")
            }

            // Ice-white nucleus — a small bright gleam at the very head, sold
            // as the comet's bright core.
            let shineColor = UIColor(red: 0.82, green: 0.93, blue: 1.0, alpha: 1.0)
            let nucleus = CAShapeLayer()
            nucleus.frame = bounds
            nucleus.path = path
            nucleus.strokeColor = shineColor.cgColor
            nucleus.fillColor = UIColor.clear.cgColor
            nucleus.lineWidth = 2.2
            nucleus.lineCap = .round
            nucleus.lineJoin = .round
            nucleus.strokeStart = 0
            nucleus.strokeEnd = 0
            nucleus.shadowColor = UIColor.white.cgColor
            nucleus.shadowOpacity = 0.75
            nucleus.shadowRadius = 3
            nucleus.shadowOffset = .zero
            region.layer.addSublayer(nucleus)
            revealLayers.append(nucleus)

            nucleus.add(makeHeadAnim(), forKey: "head")
            nucleus.add(makeTailAnim(dashFraction: 0.02), forKey: "tail")

            // Tear everything down once the full comet has retracted.
            let allLayers: [CALayer] = createdLayers + [nucleus]
            let cleanup = DispatchWorkItem { [weak self] in
                for layer in allLayers {
                    layer.removeFromSuperlayer()
                }
                guard let self else { return }
                self.revealLayers.removeAll { layer in
                    allLayers.contains(where: { $0 === layer })
                }
            }
            revealCleanupItems.append(cleanup)
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.05, execute: cleanup)
        }

        /// Open-ended rounded-rect contour: starts on the right edge at the
        /// "+" badge's bottom perimeter intersection, runs clockwise (down →
        /// left → up → right) around the bbox, and ends on the top edge at
        /// the badge's left perimeter intersection. The top-right corner is
        /// intentionally skipped because the badge sits over it, so the line
        /// emerges from one side of the icon and retracts back into the
        /// other side — touching the edge of the icon on both ends.
        ///
        /// Geometry: badge frame `(insetRect.width-17, -3, 20, 20)` →
        /// center `(maxX - 7, 7)`, radius 10. The 7-7 offset from the corner
        /// makes both edge intersections symmetric — each sits `7 + √51 ≈
        /// 14.14pt` from the corner along its respective edge.
        static func contourPath(in bounds: CGRect, cornerRadius r: CGFloat) -> CGPath {
            let path = UIBezierPath()
            let minX = bounds.minX, maxX = bounds.maxX
            let minY = bounds.minY, maxY = bounds.maxY

            let badgeOffset: CGFloat = 7 + sqrt(51)

            // Start on the right edge, at the badge's bottom-side perimeter.
            path.move(to: CGPoint(x: maxX, y: minY + badgeOffset))

            // Right edge going down
            path.addLine(to: CGPoint(x: maxX, y: maxY - r))
            // Bottom-right arc: right → bottom
            path.addArc(
                withCenter: CGPoint(x: maxX - r, y: maxY - r),
                radius: r,
                startAngle: 0,
                endAngle: .pi / 2,
                clockwise: true
            )
            // Bottom edge going left
            path.addLine(to: CGPoint(x: minX + r, y: maxY))
            // Bottom-left arc: bottom → left
            path.addArc(
                withCenter: CGPoint(x: minX + r, y: maxY - r),
                radius: r,
                startAngle: .pi / 2,
                endAngle: .pi,
                clockwise: true
            )
            // Left edge going up
            path.addLine(to: CGPoint(x: minX, y: minY + r))
            // Top-left arc: left → top
            path.addArc(
                withCenter: CGPoint(x: minX + r, y: minY + r),
                radius: r,
                startAngle: .pi,
                endAngle: 3 * .pi / 2,
                clockwise: true
            )
            // Top edge going right to the badge's left-side perimeter
            path.addLine(to: CGPoint(x: maxX - badgeOffset, y: minY))

            return path.cgPath
        }

        /// Badge → "✓" in green. Leaves the region outline alone: after the
        /// reveal animation the bbox outline is transparent, so toggling
        /// state must not resurrect it.
        private func applyAddedStyle(to region: UIView) {
            let green = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
            if let badge = region.viewWithTag(300) {
                badge.backgroundColor = green
                badge.layer.shadowColor = green.cgColor
                badge.layer.shadowOpacity = 0.45
                badge.layer.shadowRadius = 6
                if let icon = badge.viewWithTag(301) as? UIImageView {
                    icon.image = UIImage(
                        systemName: "checkmark",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: Self.badgeIconSize, weight: .heavy)
                    )
                }
            }
        }

        /// Badge → "+" in the premium blue. Same rule as `applyAddedStyle`:
        /// do not touch the region outline.
        private func applyDefaultStyle(to region: UIView) {
            let blue = Self.premiumBlueColor
            if let badge = region.viewWithTag(300) {
                badge.backgroundColor = blue
                badge.layer.shadowColor = blue.cgColor
                badge.layer.shadowOpacity = 0.35
                badge.layer.shadowRadius = 5
                if let icon = badge.viewWithTag(301) as? UIImageView {
                    icon.image = UIImage(
                        systemName: "plus",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: Self.badgeIconSize, weight: .bold)
                    )
                }
            }
        }

        private func revertDotForRemovedItem(hotspot: PromoFolderHotspot) {
            guard let region = hotspotDots.first(where: { $0.accessibilityIdentifier == hotspot.itemId }) else { return }

            UIView.animate(withDuration: 0.3) {
                self.applyDefaultStyle(to: region)
            } completion: { _ in
                guard let badge = region.viewWithTag(300) else { return }
                UIView.animate(withDuration: 0.12, animations: {
                    badge.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
                }) { _ in
                    UIView.animate(withDuration: 0.2,
                                   delay: 0,
                                   usingSpringWithDamping: 0.6,
                                   initialSpringVelocity: 0.8) {
                        badge.transform = .identity
                    }
                }
            }
        }

        private func updateDotForAddedItem(hotspot: PromoFolderHotspot, in imageView: UIImageView) {
            guard let region = hotspotDots.first(where: { $0.accessibilityIdentifier == hotspot.itemId }) else { return }

            UIView.animate(withDuration: 0.3) {
                self.applyAddedStyle(to: region)
            } completion: { _ in
                guard let badge = region.viewWithTag(300) else { return }
                UIView.animate(withDuration: 0.15, animations: {
                    badge.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                }) { _ in
                    UIView.animate(withDuration: 0.2,
                                   delay: 0,
                                   usingSpringWithDamping: 0.5,
                                   initialSpringVelocity: 0.9) {
                        badge.transform = .identity
                    }
                }
            }
        }

        // MARK: - Image Loading

        func loadImage(url: String, containerSize: CGSize) {
            guard let imageURL = URL(string: url) else { return }

            // Sync cache hit: paint on the same frame, no spinner, no async hop.
            // This is what makes fast-swipe back to a seen page feel instant.
            if let cached = ImagePrefetcher.shared.cachedImage(for: imageURL) {
                applyLoadedImage(cached, containerSize: containerSize)
                return
            }

            Task { @MainActor in
                // Route misses through ImagePrefetcher so concurrent page renders
                // (TabView pre-rendering neighbors, swipe-back mid-fetch) dedupe
                // on the same in-flight Task instead of firing parallel requests.
                guard let image = await ImagePrefetcher.shared.prefetch(url: imageURL).value else {
                    print("[FolderPage] Failed to load image: \(imageURL)")
                    return
                }
                applyLoadedImage(image, containerSize: containerSize)
            }
        }

        @MainActor
        private func applyLoadedImage(_ image: UIImage, containerSize: CGSize) {
            imageView?.image = image
            imageView?.frame = CGRect(origin: .zero, size: containerSize)

            if let spinner = scrollView?.viewWithTag(200) as? UIActivityIndicatorView {
                spinner.stopAnimating()
                spinner.isHidden = true
            }

            // Add hotspot dots after image loads. The reveal-all trace is
            // driven by page visibility (`pageBecameVisible`) — see the
            // comment above `maybeRunReveal`. The deep-link spotlight
            // still fires here once, and is mutually exclusive with the
            // reveal-all (running both at once looked like random lines).
            if let imageView {
                addHotspotDots(in: imageView)
                imageLoaded = true
                maybeRunReveal()
                maybeRunSpotlight(in: imageView)
            }
        }

        // MARK: - Spotlight (deep-link highlight)

        private func maybeRunSpotlight(in imageView: UIImageView) {
            guard !didRunSpotlight,
                  let targetId = highlightItemId,
                  let hotspot = hotspots.first(where: { $0.itemId == targetId }) else { return }
            didRunSpotlight = true
            // Short delay so the push transition settles before the contour starts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak imageView] in
                guard let self, let imageView else { return }
                self.showSpotlightFeedback(for: hotspot, in: imageView)
            }
        }

        /// Draws a premium-blue line around the promo's exact bbox when the
        /// viewer opens from a deep link. The line:
        ///   1. emerges clockwise from the top-right (where the "+" badge sits),
        ///   2. completes the full contour, and
        ///   3. pulses its glow a couple of times before fading out.
        /// A soft dim frames the surrounding page without hiding it.
        private func showSpotlightFeedback(for hotspot: PromoFolderHotspot, in imageView: UIImageView) {
            let imageRect = displayedImageRect(in: imageView)
            let rect = hotspot.tileRect(in: imageRect)
            let accent = Self.premiumBlueColor

            let holeRect = rect.insetBy(dx: -4, dy: -4)
            let cornerRadius: CGFloat = 10

            // Single overlay view owns both the dim and the contour — one subview,
            // one fade-out, nothing left hanging.
            let overlay = UIView(frame: imageView.bounds)
            overlay.backgroundColor = .clear
            overlay.isUserInteractionEnabled = false
            overlay.alpha = 0

            // Dim — an even-odd fill with the bbox cut out.
            let dimPath = UIBezierPath(rect: imageView.bounds)
            dimPath.append(UIBezierPath(roundedRect: holeRect, cornerRadius: cornerRadius))
            dimPath.usesEvenOddFillRule = true

            let dimLayer = CAShapeLayer()
            dimLayer.frame = imageView.bounds
            dimLayer.path = dimPath.cgPath
            dimLayer.fillRule = .evenOdd
            dimLayer.fillColor = UIColor.black.withAlphaComponent(0.45).cgColor
            overlay.layer.addSublayer(dimLayer)

            // Contour — clockwise stroke starting at the top-right under the
            // "+" badge, so the line "emerges" from a natural anchor.
            // Path coords are absolute in imageView space; leave frame/position
            // at their defaults so the stroke lands exactly on the bbox.
            let contour = CAShapeLayer()
            contour.frame = imageView.bounds
            contour.path = Self.spotlightContourPath(in: holeRect, cornerRadius: cornerRadius)
            contour.fillColor = UIColor.clear.cgColor
            contour.strokeColor = accent.cgColor
            contour.lineWidth = 2.5
            contour.lineCap = .round
            contour.lineJoin = .round
            contour.strokeEnd = 0
            contour.shadowColor = accent.cgColor
            contour.shadowOpacity = 0.85
            contour.shadowRadius = 6
            contour.shadowOffset = .zero
            overlay.layer.addSublayer(contour)

            imageView.addSubview(overlay)

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // 1. Dim + stroke reveal run in parallel.
            UIView.animate(withDuration: 0.2) {
                overlay.alpha = 1
            }

            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0.0
            draw.toValue = 1.0
            draw.duration = 0.4
            draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
            draw.fillMode = .forwards
            draw.isRemovedOnCompletion = false
            contour.strokeEnd = 1
            contour.add(draw, forKey: "draw")

            // 2. One glow breath right as the line lands — quick acknowledgement.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak contour] in
                guard let contour else { return }
                let pulse = CABasicAnimation(keyPath: "shadowOpacity")
                pulse.fromValue = 0.85
                pulse.toValue = 0.3
                pulse.duration = 0.3
                pulse.autoreverses = true
                pulse.repeatCount = 1
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                contour.add(pulse, forKey: "pulse")
            }

            // 3. Short hold, then fade everything out together.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                UIView.animate(withDuration: 0.3) {
                    overlay.alpha = 0
                } completion: { _ in
                    overlay.removeFromSuperview()
                }
            }
        }

        /// Rounded-rect path that starts at the top edge under where a "+" badge
        /// would sit and runs clockwise — so `strokeEnd` 0→1 reveals the line
        /// emerging from the same anchor used by the page-load contour trace.
        private static func spotlightContourPath(in bounds: CGRect, cornerRadius r: CGFloat) -> CGPath {
            let path = UIBezierPath()
            let minX = bounds.minX, maxX = bounds.maxX
            let minY = bounds.minY, maxY = bounds.maxY

            path.move(to: CGPoint(x: maxX - r, y: minY))
            path.addArc(withCenter: CGPoint(x: maxX - r, y: minY + r),
                        radius: r, startAngle: 3 * .pi / 2, endAngle: 2 * .pi, clockwise: true)
            path.addLine(to: CGPoint(x: maxX, y: maxY - r))
            path.addArc(withCenter: CGPoint(x: maxX - r, y: maxY - r),
                        radius: r, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: minX + r, y: maxY))
            path.addArc(withCenter: CGPoint(x: minX + r, y: maxY - r),
                        radius: r, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: minX, y: minY + r))
            path.addArc(withCenter: CGPoint(x: minX + r, y: minY + r),
                        radius: r, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: maxX - r, y: minY))
            return path.cgPath
        }
    }
}

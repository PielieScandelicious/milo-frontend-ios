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
                        Text(folder.folderName)
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
            prefetchHeroImages(around: currentPage)
            await prefetchSimilarPromos(forPage: currentPage)
        }
    }

    /// Prefetch the full-tile hero crops for the visible page (and its immediate
    /// neighbors) so that when a user taps a hotspot the detail sheet's hero
    /// paints from cache instead of showing a ProgressView flash.
    private func prefetchHeroImages(around pageIndex: Int) {
        let range = max(0, pageIndex - 1)...min(folder.pages.count - 1, pageIndex + 1)
        for index in range where index < folder.pages.count {
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

                // Circular "+" button in the top-right corner — clearly tappable
                // shortcut that toggles the item in the grocery list directly
                // (bypasses detail sheet).
                let blue = Self.premiumBlueColor
                let badgeSize = Coordinator.badgeSize
                let badge = UIView(frame: CGRect(
                    x: insetRect.width - badgeSize + 3,
                    y: -3,
                    width: badgeSize,
                    height: badgeSize
                ))
                badge.backgroundColor = blue
                badge.layer.cornerRadius = badgeSize / 2
                badge.layer.shadowColor = blue.cgColor
                badge.layer.shadowOpacity = 0.35
                badge.layer.shadowOffset = CGSize(width: 0, height: 2)
                badge.layer.shadowRadius = 5
                badge.tag = 300

                let iconSize = Coordinator.badgeIconSize
                let iconView = UIImageView(image: UIImage(
                    systemName: "plus",
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

        /// On page load, a single premium-blue stroke traces the complete
        /// contour of every hotspot bbox, then retracts and vanishes — leaving
        /// only the "+" badge as the persistent affordance.
        ///
        /// The trace is a "chasing snake": `strokeEnd` runs 0→1 to draw the
        /// perimeter, then `strokeStart` catches up 0→1 to erase it from the
        /// tail. Staggered across all regions for an elegant cascade, paired
        /// with a light haptic cue.
        private func animateHotspotReveal() {
            guard !hotspotDots.isEmpty else { return }

            // Soft haptic to cue the reveal — light, not intrusive.
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            impact.impactOccurred(intensity: 0.4)

            let stagger: TimeInterval = 0.08
            for (index, region) in hotspotDots.enumerated() {
                let delay = Double(index) * stagger
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak region] in
                    guard let self, let region else { return }
                    self.traceContour(on: region, color: Self.premiumBlueColor)
                }
            }
        }

        /// Draws a premium-blue stroke around the region's rounded-rect
        /// perimeter, then erases it from the start — like a snake chasing
        /// its tail. The path is anchored so the stroke emerges from and
        /// retracts back into the top-right corner, where the "+" badge sits.
        /// The layer is removed once both animations complete.
        private func traceContour(on region: UIView, color: UIColor) {
            let bounds = region.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }

            let path = Self.contourPath(in: bounds, cornerRadius: 8)

            let line = CAShapeLayer()
            line.frame = bounds
            line.path = path
            line.strokeColor = color.cgColor
            line.fillColor = UIColor.clear.cgColor
            line.lineWidth = 2.0
            line.lineCap = .round
            line.lineJoin = .round
            line.strokeStart = 0
            line.strokeEnd = 0
            // Soft bloom so the line reads premium against any folder image.
            line.shadowColor = color.cgColor
            line.shadowOpacity = 0.85
            line.shadowRadius = 5
            line.shadowOffset = .zero
            region.layer.addSublayer(line)

            // A short dash (≈15% of the perimeter) travels clockwise around
            // the bbox. Head (`strokeEnd`) and tail (`strokeStart`) are both
            // keyframed to start at the same timestamp — the tail simply
            // holds at 0 for the first `dashFraction` before moving, and the
            // head holds at 1 for the last `dashFraction` after finishing.
            // Result: the dash emerges from under the "+" badge, cruises
            // around, and retracts back into it, with both animations
            // beginning in unison.
            let totalDuration: CFTimeInterval = 1.35
            let dashFraction: Double = 0.15
            let timing = CAMediaTimingFunction(name: .easeInEaseOut)
            let linear = CAMediaTimingFunction(name: .linear)
            let now = CACurrentMediaTime()

            let head = CAKeyframeAnimation(keyPath: "strokeEnd")
            head.values = [0, 1, 1]
            head.keyTimes = [0, NSNumber(value: 1 - dashFraction), 1]
            head.timingFunctions = [timing, linear]
            head.duration = totalDuration
            head.beginTime = now
            head.fillMode = .forwards
            head.isRemovedOnCompletion = false
            line.add(head, forKey: "head")

            let tail = CAKeyframeAnimation(keyPath: "strokeStart")
            tail.values = [0, 0, 1]
            tail.keyTimes = [0, NSNumber(value: dashFraction), 1]
            tail.timingFunctions = [linear, timing]
            tail.duration = totalDuration
            tail.beginTime = now
            tail.fillMode = .forwards
            tail.isRemovedOnCompletion = false
            line.add(tail, forKey: "tail")

            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.05) { [weak line] in
                line?.removeFromSuperlayer()
            }
        }

        /// Rounded-rect stroke path that starts and ends at the top-right
        /// corner — specifically at the top-edge anchor under the "+" badge —
        /// and runs clockwise. Because both endpoints sit under the badge,
        /// `strokeEnd` 0→1 makes the line emerge from the "+" and grow around
        /// the contour, while `strokeStart` 0→1 makes the tail retract back
        /// into the "+". The stroke always appears from and vanishes into
        /// the badge.
        static func contourPath(in bounds: CGRect, cornerRadius r: CGFloat) -> CGPath {
            let path = UIBezierPath()
            let minX = bounds.minX, maxX = bounds.maxX
            let minY = bounds.minY, maxY = bounds.maxY

            // Anchor: top edge, just to the left of the top-right arc.
            path.move(to: CGPoint(x: maxX - r, y: minY))

            // Top-right arc: top → right
            path.addArc(
                withCenter: CGPoint(x: maxX - r, y: minY + r),
                radius: r,
                startAngle: 3 * .pi / 2,
                endAngle: 2 * .pi,
                clockwise: true
            )
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
            // Top edge back to the anchor under the "+" badge
            path.addLine(to: CGPoint(x: maxX - r, y: minY))

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

            Task { @MainActor in
                do {
                    let (data, _) = try await URLSession.shared.data(from: imageURL)
                    guard let image = UIImage(data: data) else { return }

                    imageView?.image = image
                    imageView?.frame = CGRect(origin: .zero, size: containerSize)

                    // Hide spinner
                    if let spinner = scrollView?.viewWithTag(200) as? UIActivityIndicatorView {
                        spinner.stopAnimating()
                        spinner.isHidden = true
                    }

                    // Add hotspot dots after image loads. When the viewer was
                    // opened to spotlight a specific promo, skip the reveal-all
                    // trace — the single bbox contour animation is the signal,
                    // and running both at once looked like random lines.
                    if let imageView {
                        addHotspotDots(in: imageView)
                        if highlightItemId == nil {
                            animateHotspotReveal()
                        }
                        maybeRunSpotlight(in: imageView)
                    }
                } catch {
                    print("[FolderPage] Failed to load image: \(error.localizedDescription)")
                }
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

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
    @State private var currentPage: Int = 0
    @State private var selectedHotspot: PromoFolderHotspot?
    @ObservedObject private var groceryStore = GroceryListStore.shared
    @Environment(\.dismiss) private var dismiss

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
                        groceryStore: groceryStore,
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
                HStack(spacing: 8) {
                    StoreLogoView(storeName: folder.storeId, height: 16)
                        .frame(width: 24, height: 24)
                    Text(folder.folderName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
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
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
    let groceryStore: GroceryListStore
    let onInfoTap: (PromoFolderHotspot) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZoomableImageContainer(
                imageUrl: imageUrl,
                containerSize: geometry.size,
                hotspots: hotspots,
                storeAccentColor: UIColor(storeAccentColor),
                storeName: storeName,
                groceryStore: groceryStore,
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
    let groceryStore: GroceryListStore
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

        // Double-tap to zoom
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        // Single-tap for hotspot detection (requires double-tap to fail first)
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
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
        context.coordinator.groceryStore = groceryStore
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
        var groceryStore: GroceryListStore?
        var onInfoTap: ((PromoFolderHotspot) -> Void)?
        private var hotspotDots: [UIView] = []
        private var groceryCancellable: AnyCancellable?

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

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = gesture.location(in: imageView)
                let zoomRect = CGRect(
                    x: location.x - 50,
                    y: location.y - 50,
                    width: 100,
                    height: 100
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

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
                    groceryStore?.add(item: item, storeName: storeName)
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
            let badgeWidth = Self.badgeWidth
            let badgeHeight = Self.badgeHeight
            let badgeX = insetRect.maxX - badgeWidth + 4
            let badgeY = insetRect.minY - 4
            // Expand hit target slightly so it's forgiving to tap.
            return CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
                .insetBy(dx: -6, dy: -6)
        }

        static let badgeWidth: CGFloat = 66
        static let badgeHeight: CGFloat = 22

        /// Unified premium accent used for hotspot outlines and the ADD pill
        /// across every store's folder — a refined graphite ink that reads
        /// high-end on any background.
        static let premiumAccentColor = UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1.0)

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

                // Highlighted region covering the whole hotspot area —
                // uses a unified premium graphite accent across all stores.
                let accent = Self.premiumAccentColor
                let region = UIView(frame: insetRect)
                region.backgroundColor = accent.withAlphaComponent(0.06)
                region.layer.cornerRadius = 8
                region.layer.borderColor = accent.withAlphaComponent(0.30).cgColor
                region.layer.borderWidth = 1.0
                region.alpha = 0
                region.accessibilityIdentifier = hotspot.itemId
                region.isUserInteractionEnabled = false

                // "+ ADD" pill in the top-right corner — clearly tappable shortcut
                // that adds the item to the grocery list directly (bypasses detail sheet).
                let badgeWidth = Coordinator.badgeWidth
                let badgeHeight = Coordinator.badgeHeight
                let badge = UIView(frame: CGRect(
                    x: insetRect.width - badgeWidth + 3,
                    y: -3,
                    width: badgeWidth,
                    height: badgeHeight
                ))
                badge.backgroundColor = accent.withAlphaComponent(0.88)
                badge.layer.cornerRadius = badgeHeight / 2
                badge.layer.shadowColor = UIColor.black.cgColor
                badge.layer.shadowOpacity = 0.22
                badge.layer.shadowOffset = CGSize(width: 0, height: 1)
                badge.layer.shadowRadius = 3
                badge.tag = 300

                let iconSize: CGFloat = 10
                let iconView = UIImageView(image: UIImage(
                    systemName: "plus",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
                ))
                iconView.tintColor = .white
                iconView.contentMode = .scaleAspectFit
                iconView.frame = CGRect(x: 8, y: (badgeHeight - iconSize) / 2, width: iconSize, height: iconSize)
                iconView.tag = 301
                badge.addSubview(iconView)

                let labelX = 8 + iconSize + 3
                let label = UILabel(frame: CGRect(
                    x: labelX,
                    y: 0,
                    width: badgeWidth - labelX - 4,
                    height: badgeHeight
                ))
                label.text = "ADD"
                label.font = .systemFont(ofSize: 10, weight: .bold)
                label.textColor = .white
                label.textAlignment = .left
                label.adjustsFontSizeToFitWidth = false
                label.lineBreakMode = .byClipping
                label.tag = 302
                badge.addSubview(label)

                region.addSubview(badge)

                imageView.addSubview(region)
                hotspotDots.append(region)

                let promoItem = hotspot.toPromoStoreItem()
                if let store = groceryStore, store.contains(item: promoItem, storeName: storeName) {
                    applyAddedStyle(to: region)
                }

                let delay = 0.6 + Double(hotspotDots.count - 1) * 0.04
                UIView.animate(withDuration: 0.35, delay: delay, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                    region.alpha = 1
                }
            }
        }

        private func applyAddedStyle(to region: UIView) {
            let green = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
            region.backgroundColor = green.withAlphaComponent(0.10)
            region.layer.borderColor = green.withAlphaComponent(0.4).cgColor
            if let badge = region.viewWithTag(300) {
                badge.backgroundColor = green
                if let icon = badge.viewWithTag(301) as? UIImageView {
                    icon.image = UIImage(
                        systemName: "checkmark",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .heavy)
                    )
                }
                if let label = badge.viewWithTag(302) as? UILabel {
                    label.text = "ADDED"
                }
            }
        }

        private func applyDefaultStyle(to region: UIView) {
            let accent = Self.premiumAccentColor
            region.backgroundColor = accent.withAlphaComponent(0.06)
            region.layer.borderColor = accent.withAlphaComponent(0.30).cgColor
            if let badge = region.viewWithTag(300) {
                badge.backgroundColor = accent.withAlphaComponent(0.88)
                if let icon = badge.viewWithTag(301) as? UIImageView {
                    icon.image = UIImage(
                        systemName: "plus",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
                    )
                }
                if let label = badge.viewWithTag(302) as? UILabel {
                    label.text = "ADD"
                }
            }
        }

        private func revertDotForRemovedItem(hotspot: PromoFolderHotspot) {
            guard let region = hotspotDots.first(where: { $0.accessibilityIdentifier == hotspot.itemId }) else { return }

            if let badge = region.viewWithTag(300) {
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

            UIView.animate(withDuration: 0.3) {
                self.applyDefaultStyle(to: region)
            }
        }

        private func updateDotForAddedItem(hotspot: PromoFolderHotspot, in imageView: UIImageView) {
            guard let region = hotspotDots.first(where: { $0.accessibilityIdentifier == hotspot.itemId }) else { return }

            if let badge = region.viewWithTag(300) {
                UIView.animate(withDuration: 0.15, animations: {
                    badge.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                }) { _ in
                    UIView.animate(withDuration: 0.2,
                                   delay: 0,
                                   usingSpringWithDamping: 0.5,
                                   initialSpringVelocity: 0.9) {
                        badge.transform = .identity
                    }
                }
            }

            UIView.animate(withDuration: 0.3) {
                self.applyAddedStyle(to: region)
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

                    // Add hotspot dots after image loads
                    if let imageView {
                        addHotspotDots(in: imageView)
                    }
                } catch {
                    print("[FolderPage] Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }
}

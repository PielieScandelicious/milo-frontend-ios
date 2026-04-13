//
//  PromoFolderPageViewer.swift
//  Scandalicious
//
//  Full-screen promo folder page viewer with swipe-to-flip, pinch-to-zoom,
//  and interactive hotspot overlays for adding items to the grocery list.
//

import SwiftUI

struct PromoFolderPageViewer: View {
    let folder: PromoFolder
    @State private var currentPage: Int = 0
    @State private var showGroceryList = false
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
                        groceryStore: groceryStore
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
            ToolbarItem(placement: .topBarLeading) {
                GroceryListToolbarButton(count: groceryStore.activeItemCount) {
                    showGroceryList = true
                }
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    StoreLogoView(storeName: folder.storeId, height: 16)
                        .frame(width: 24, height: 24)
                    Text(folder.folderName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if let url = URL(string: folder.sourceUrl), !folder.sourceUrl.isEmpty {
                    Link(destination: url) {
                        Image(systemName: "safari")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .sheet(isPresented: $showGroceryList) {
            GroceryListSheet()
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

    var body: some View {
        GeometryReader { geometry in
            ZoomableImageContainer(
                imageUrl: imageUrl,
                containerSize: geometry.size,
                hotspots: hotspots,
                storeAccentColor: UIColor(storeAccentColor),
                storeName: storeName,
                groceryStore: groceryStore
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
        private var hotspotDots: [UIView] = []

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

            // Check if already in grocery list
            let promoItem = hotspot.toPromoStoreItem()
            guard let store = groceryStore else { return }

            if store.contains(item: promoItem, storeName: storeName) {
                showAlreadyAddedFeedback(for: hotspot, in: imageView)
            } else {
                store.add(item: promoItem, storeName: storeName)
                showAddedFeedback(for: hotspot, in: imageView)

                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }

        // MARK: - Visual Feedback

        private func showAddedFeedback(for hotspot: PromoFolderHotspot, in imageView: UIImageView) {
            let rect = hotspot.tileRect(in: displayedImageRect(in: imageView))

            // Highlight rectangle
            let highlight = UIView(frame: rect)
            highlight.backgroundColor = storeAccentColor.withAlphaComponent(0.15)
            highlight.layer.borderColor = storeAccentColor.withAlphaComponent(0.4).cgColor
            highlight.layer.borderWidth = 1.5
            highlight.layer.cornerRadius = 6
            highlight.alpha = 0
            imageView.addSubview(highlight)

            // Checkmark icon
            let checkSize: CGFloat = 32
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            checkmark.tintColor = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
            checkmark.frame = CGRect(
                x: rect.midX - checkSize / 2,
                y: rect.midY - checkSize / 2,
                width: checkSize,
                height: checkSize
            )
            checkmark.alpha = 0
            checkmark.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            imageView.addSubview(checkmark)

            UIView.animate(withDuration: 0.15) {
                highlight.alpha = 1
                checkmark.alpha = 1
                checkmark.transform = .identity
            } completion: { _ in
                UIView.animate(withDuration: 0.3, delay: 0.4) {
                    highlight.alpha = 0
                    checkmark.alpha = 0
                    checkmark.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                } completion: { _ in
                    highlight.removeFromSuperview()
                    checkmark.removeFromSuperview()
                }
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

                // Highlighted region covering the whole hotspot area
                let region = UIView(frame: insetRect)
                region.backgroundColor = storeAccentColor.withAlphaComponent(0.08)
                region.layer.cornerRadius = 8
                region.layer.borderColor = storeAccentColor.withAlphaComponent(0.35).cgColor
                region.layer.borderWidth = 1.5
                region.alpha = 0
                region.accessibilityIdentifier = hotspot.itemId
                region.isUserInteractionEnabled = false

                // "+" badge in the top-right corner
                let badgeSize: CGFloat = 24
                let badge = UIView(frame: CGRect(
                    x: insetRect.width - badgeSize + 4,
                    y: -4,
                    width: badgeSize,
                    height: badgeSize
                ))
                badge.backgroundColor = storeAccentColor
                badge.layer.cornerRadius = badgeSize / 2
                badge.layer.shadowColor = UIColor.black.cgColor
                badge.layer.shadowOpacity = 0.3
                badge.layer.shadowOffset = CGSize(width: 0, height: 1)
                badge.layer.shadowRadius = 3
                badge.tag = 300

                let iconSize: CGFloat = 13
                let iconView = UIImageView(image: UIImage(
                    systemName: "plus",
                    withConfiguration: UIImage.SymbolConfiguration(weight: .bold)
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
                        withConfiguration: UIImage.SymbolConfiguration(weight: .bold)
                    )
                }
            }
        }

        private func updateDotForAddedItem(hotspot: PromoFolderHotspot, in imageView: UIImageView) {
            guard let region = hotspotDots.first(where: { $0.accessibilityIdentifier == hotspot.itemId }) else { return }

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

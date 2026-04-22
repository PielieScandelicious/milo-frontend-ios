//
//  RemoteImage.swift
//  Scandalicious
//

import SwiftUI
import UIKit

/// Shared in-memory image cache + prefetcher used by grocery list rows so that
/// images already seen on the promo screens appear instantly instead of flashing
/// through `AsyncImage`'s ProgressView while the bytes re-download.
final class ImagePrefetcher {
    static let shared = ImagePrefetcher()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 300
        c.totalCostLimit = 64 * 1024 * 1024 // 64 MB
        return c
    }()

    private var inflight: [NSURL: Task<UIImage?, Never>] = [:]
    private let queue = DispatchQueue(label: "ImagePrefetcher.inflight")

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    @discardableResult
    func prefetch(url: URL) -> Task<UIImage?, Never> {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return Task { cached }
        }
        return queue.sync {
            if let existing = inflight[key] {
                return existing
            }
            let task = Task<UIImage?, Never> { [weak self] in
                defer {
                    self?.queue.sync { _ = self?.inflight.removeValue(forKey: key) }
                }
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let image = UIImage(data: data) else { return nil }
                    self?.cache.setObject(image, forKey: key, cost: data.count)
                    return image
                } catch {
                    return nil
                }
            }
            inflight[key] = task
            return task
        }
    }

    func prefetch(urlString: String?) {
        guard let s = urlString, let url = URL(string: s) else { return }
        prefetch(url: url)
    }
}

/// Drop-in replacement for a simple `AsyncImage` that checks the shared image
/// cache synchronously on the first render, avoiding the ProgressView flash for
/// URLs that have already been prefetched.
struct RemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        // Pre-populate from the cache synchronously so the first render already
        // shows the image instead of flashing the placeholder for one frame.
        if let url, let cached = ImagePrefetcher.shared.cachedImage(for: url) {
            self._image = State(initialValue: cached)
        }
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let cached = ImagePrefetcher.shared.cachedImage(for: url) {
                self.image = cached
                return
            }
            let loaded = await ImagePrefetcher.shared.prefetch(url: url).value
            if !Task.isCancelled {
                self.image = loaded
            }
        }
    }
}

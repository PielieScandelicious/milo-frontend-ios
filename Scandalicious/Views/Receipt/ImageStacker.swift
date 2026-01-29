import UIKit

/// Simple utility for vertically stacking receipt section images
/// No complex alignment - Claude Vision API handles text recognition from the stacked image
enum ImageStacker {

    /// Stacks images vertically with a small gap between sections
    /// - Parameters:
    ///   - images: Array of images to stack (top to bottom order)
    ///   - gap: Space between images in points (default: 4)
    /// - Returns: Single vertically stacked image
    static func stack(_ images: [UIImage], gap: CGFloat = 4) -> UIImage? {
        guard !images.isEmpty else { return nil }
        guard images.count > 1 else { return images.first }

        // Normalize all images to the same width
        let targetWidth = images.map { $0.size.width }.max() ?? 0

        let normalizedImages = images.map { image -> UIImage in
            if abs(image.size.width - targetWidth) < 10 {
                return image
            }
            let scale = targetWidth / image.size.width
            let newSize = CGSize(width: targetWidth, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        // Calculate total height
        let totalHeight = normalizedImages.reduce(0) { $0 + $1.size.height } + gap * CGFloat(normalizedImages.count - 1)
        let finalSize = CGSize(width: targetWidth, height: totalHeight)

        // Render the stacked image
        let renderer = UIGraphicsImageRenderer(size: finalSize)
        return renderer.image { context in
            var yOffset: CGFloat = 0

            for (index, image) in normalizedImages.enumerated() {
                image.draw(at: CGPoint(x: 0, y: yOffset))
                yOffset += image.size.height

                // Add visual separator line between sections (subtle)
                if index < normalizedImages.count - 1 {
                    let separatorRect = CGRect(x: 0, y: yOffset, width: targetWidth, height: gap)
                    UIColor(white: 0.9, alpha: 1.0).setFill()
                    context.fill(separatorRect)
                    yOffset += gap
                }
            }
        }
    }
}

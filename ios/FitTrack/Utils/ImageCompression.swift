import Foundation
import UIKit

/// Shared image compression used by `ProgressPhoto` (and eventually any other
/// photo write path that syncs via CloudKit). Two goals:
///
/// 1. Bound the JPEG size so CloudKit asset sync stays quick even on cell —
///    a ~12 MP iPhone capture at full quality is ~3–5 MB; after downscale
///    + 0.8 quality it lands around 180–350 KB without visible loss for a
///    progress-photo use case.
/// 2. Do the heavy lifting off-main so we don't hitch the picker callback
///    — `UIImage.jpegData(compressionQuality:)` on a full-res photo can
///    cost 80–200 ms on A15-class hardware.
///
/// Usage:
///     let jpeg = await ImageCompression.compressedJPEG(from: data)
///
/// Returns nil only if `Data` can't be decoded as an image at all.
enum ImageCompression {
    /// Longest-edge cap for downscaled output, in pixels. 1600 is the sweet
    /// spot for progress photos: visible detail on a 6.7" device at 3x is
    /// ~1290 px wide, so 1600 covers that with headroom and lines up with
    /// common social-media upload targets.
    static let defaultMaxEdge: CGFloat = 1600

    /// Compression quality handed to `UIImage.jpegData(...)`. 0.8 is a
    /// near-invisible drop in quality and roughly 1/3 the bytes of 1.0.
    static let defaultQuality: CGFloat = 0.8

    /// Compress arbitrary image `Data` for CloudKit-synced storage.
    /// Runs on a detached user-initiated Task so the caller's actor
    /// (usually main) doesn't hitch.
    static func compressedJPEG(
        from data: Data,
        maxEdge: CGFloat = defaultMaxEdge,
        quality: CGFloat = defaultQuality
    ) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let original = UIImage(data: data) else { return nil }
            let resized = original.downscaled(maxEdge: maxEdge)
            return resized.jpegData(compressionQuality: quality)
        }.value
    }

    /// Convenience for callers that already have a `UIImage` in hand (e.g.
    /// the camera picker's delegate).
    static func compressedJPEG(
        from image: UIImage,
        maxEdge: CGFloat = defaultMaxEdge,
        quality: CGFloat = defaultQuality
    ) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            image.downscaled(maxEdge: maxEdge).jpegData(compressionQuality: quality)
        }.value
    }
}

// MARK: - UIImage downscaling

extension UIImage {
    /// Returns a copy whose longest edge is at most `maxEdge` points. If the
    /// receiver already fits, returns `self` unchanged. Preserves aspect
    /// ratio and respects `scale` so the output has the correct pixel size.
    fileprivate func downscaled(maxEdge: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxEdge else { return self }

        let ratio = maxEdge / longest
        let newSize = CGSize(
            width:  floor(size.width  * ratio),
            height: floor(size.height * ratio)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale          // keep 2x/3x fidelity
        format.opaque = true          // JPEG has no alpha — opaque is a free speedup

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

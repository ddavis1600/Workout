import Foundation
import UIKit

/// Shared image compression used by every CloudKit-backed (or
/// Documents/-backed) photo write path. Two goals:
///
/// 1. Bound the on-disk / CKAsset size so sync stays quick on cell —
///    a ~12 MP iPhone capture at full quality is ~3–5 MB; after
///    downscale + 0.8 quality it lands around 180–350 KB without
///    visible loss for the photo sizes we actually render
///    (meal thumbnails, journal entries, progress-photo grid).
/// 2. Do the heavy lifting off-main so we don't hitch the picker
///    callback — `UIImage.jpegData(compressionQuality:)` on a
///    full-res photo can cost 80–200 ms on A15-class hardware.
///
/// Usage (picker callback — bytes in hand):
///     let jpeg = await ImageCompression.compressedJPEG(from: data)
/// Usage (camera delegate — UIImage in hand):
///     let jpeg = await ImageCompression.compressedJPEG(from: image)
///
/// Returns nil only if `Data` can't be decoded as an image at all.
enum ImageCompression {
    /// Longest-edge cap for downscaled output, in pixels. 1600 covers
    /// detail on a 6.7" display at 3× (~1290 px native) with headroom,
    /// and lines up with common social-media upload targets.
    static let defaultMaxEdge: CGFloat = 1600

    /// Compression quality. 0.8 is a near-invisible drop and roughly
    /// 1/3 the bytes of 1.0.
    static let defaultQuality: CGFloat = 0.8

    /// Compress arbitrary image `Data`. Detached `userInitiated` Task
    /// so the caller's actor (usually main) doesn't hitch.
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

    /// Convenience for callers that already have a `UIImage` in hand
    /// (e.g. the camera picker's delegate).
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
    /// Returns a copy whose longest edge is at most `maxEdge` points.
    /// If the receiver already fits, returns `self`. Preserves aspect
    /// ratio and respects `scale` so the output has the correct pixel
    /// size.
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

import Foundation
import SwiftData
import UIKit

@Model
final class ProgressPhoto {
    var date: Date = Date()
    var caption: String = ""
    var createdAt: Date = Date()

    /// JPEG bytes for the photo. `@Attribute(.externalStorage)` tells
    /// SwiftData to keep the blob out of the SQLite row — under the hood
    /// it writes a sidecar file inside the model container and, crucially,
    /// hands CloudKit a CKAsset when NSPersistentCloudKitContainer syncs
    /// the record. That's what gets the actual image across devices.
    ///
    /// Optional + nil default keeps CloudKit happy: every stored property
    /// on a sync'd @Model must be Optional or have a default.
    @Attribute(.externalStorage) var imageData: Data? = nil

    init(date: Date = Date(), caption: String = "", imageData: Data? = nil) {
        self.date = date
        self.caption = caption
        self.createdAt = Date()
        self.imageData = imageData
    }

    /// Decode the on-model JPEG into a `UIImage`. Returns nil if the
    /// photo hasn't synced yet (CloudKit asset still downloading) or
    /// was never attached. Callers treat nil as "show placeholder."
    func loadImage() -> UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }

    /// Insert a new progress photo. The JPEG bytes live on the model
    /// itself (`imageData`, backed by external storage); SwiftData +
    /// NSPersistentCloudKitContainer handle the CKAsset sync from there.
    ///
    /// Callers should hand in already-compressed bytes (see
    /// `ImageCompression.compressedJPEG(...)`) — this function does not
    /// recompress. Keeps the expensive JPEG work out of the
    /// model-context save path.
    static func save(imageData: Data, date: Date, caption: String = "", context: ModelContext) {
        let photo = ProgressPhoto(date: date, caption: caption, imageData: imageData)
        context.insert(photo)
        try? context.save()
    }
}

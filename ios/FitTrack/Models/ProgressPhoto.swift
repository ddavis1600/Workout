import Foundation
import SwiftData
import UIKit

@Model
final class ProgressPhoto {
    var date: Date = Date()
    var filename: String = ""
    var caption: String = ""
    var createdAt: Date = Date()

    /// JPEG bytes for the photo. `@Attribute(.externalStorage)` tells
    /// SwiftData to keep the blob out of the SQLite row — under the hood it
    /// writes a sidecar file inside the model container and, crucially,
    /// hands CloudKit a CKAsset when NSPersistentCloudKitContainer syncs
    /// the record. That's what gets the actual image across devices.
    ///
    /// Optional + nil default keeps CloudKit happy: every stored property
    /// on a sync'd @Model must be Optional or have a default.
    @Attribute(.externalStorage) var imageData: Data? = nil

    init(date: Date = Date(), filename: String, caption: String = "") {
        self.date = date
        self.filename = filename
        self.caption = caption
        self.createdAt = Date()
    }

    static func photoDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressPhotos", isDirectory: true)
    }

    func photoURL() -> URL {
        ProgressPhoto.photoDirectory().appendingPathComponent(filename)
    }

    func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL()) else { return nil }
        return UIImage(data: data)
    }

    static func save(imageData: Data, date: Date, caption: String = "", context: ModelContext) {
        let dir = photoDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "progress_\(UUID().uuidString).jpg"
        let url = dir.appendingPathComponent(filename)
        try? imageData.write(to: url)
        let photo = ProgressPhoto(date: date, filename: filename, caption: caption)
        context.insert(photo)
        try? context.save()
    }
}

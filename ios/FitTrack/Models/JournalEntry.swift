import Foundation
import SwiftData

@Model
final class JournalEntry {
    var date: Date = Date()
    var title: String = ""
    var content: String = ""
    var mood: String = ""           // emoji or keyword
    var photoData: Data?            // JPEG compressed
    var audioFileName: String?      // filename in app documents
    var audioDuration: Double?      // seconds
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        title: String = "",
        content: String = "",
        mood: String = "",
        photoData: Data? = nil,
        audioFileName: String? = nil,
        audioDuration: Double? = nil
    ) {
        self.date = date
        self.title = title
        self.content = content
        self.mood = mood
        self.photoData = photoData
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
        self.createdAt = Date()
    }

    /// Full path to audio file in documents directory
    var audioURL: URL? {
        guard let name = audioFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(name)
    }
}

import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var muscleGroup: String
    var equipment: String?

    init(name: String, muscleGroup: String, equipment: String? = nil) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
    }
}

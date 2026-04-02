import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func formatted(as pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: self)
    }
}

// MARK: - Double Extensions

extension Double {
    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
}

// MARK: - Color Extensions

extension Color {
    static let emerald = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let slateBackground = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let slateCard = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    static let slateBorder = Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255)
    static let slateText = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
}

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
// Field Notes palette — ink + paper + olive

extension Color {
    // Primary accent: olive #556B2F
    static let emerald       = Color(red:  85 / 255, green: 107 / 255, blue:  47 / 255)
    // Backgrounds: off-white paper
    static let slateBackground = Color(red: 237 / 255, green: 232 / 255, blue: 220 / 255) // paper  #EDE8DC
    static let slateCard     = Color(red: 229 / 255, green: 223 / 255, blue: 209 / 255) // paper2 #E5DFD1
    // Border: olive 25% on paper ≈ #C7C9B1
    static let slateBorder   = Color(red: 199 / 255, green: 201 / 255, blue: 177 / 255)
    // Muted text: #8A8470
    static let slateText     = Color(red: 138 / 255, green: 132 / 255, blue: 112 / 255)
    // New tokens
    static let ink           = Color(red:  26 / 255, green:  26 / 255, blue:  20 / 255) // ink #1A1A14
    static let paper         = Color(red: 237 / 255, green: 232 / 255, blue: 220 / 255) // paper #EDE8DC
    static let oliveTint     = Color(red: 212 / 255, green: 221 / 255, blue: 184 / 255) // #D4DDB8
    static let fieldNotesAlert = Color(red: 139 / 255, green:  58 / 255, blue:  42 / 255) // alert red #8B3A2A
}

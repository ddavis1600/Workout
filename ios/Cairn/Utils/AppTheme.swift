import SwiftUI
import UIKit

// MARK: - Theme Palette

enum ThemePalette: String, CaseIterable, Identifiable {
    case fieldNotes = "fieldNotes"
    case ocean      = "ocean"
    case midnight   = "midnight"
    case ember      = "ember"
    case slate      = "slate"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fieldNotes: return "Field Notes"
        case .ocean:      return "Ocean"
        case .midnight:   return "Midnight"
        case .ember:      return "Ember"
        case .slate:      return "Slate"
        }
    }

    var tagline: String {
        switch self {
        case .fieldNotes: return "Warm olive & paper"
        case .ocean:      return "Cool teal & deep water"
        case .midnight:   return "Rich purple & indigo"
        case .ember:      return "Rust & terracotta"
        case .slate:      return "Clean blue & gray"
        }
    }

    // MARK: - Light mode UIColors

    var accentLight: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 85,  g: 107, b: 47)
        case .ocean:      return UIColor(r: 10,  g: 124, b: 140)
        case .midnight:   return UIColor(r: 107, g: 79,  b: 168)
        case .ember:      return UIColor(r: 181, g: 74,  b: 27)
        case .slate:      return UIColor(r: 44,  g: 91,  b: 170)
        }
    }
    var bgLight: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 237, g: 232, b: 220)
        case .ocean:      return UIColor(r: 234, g: 244, b: 246)
        case .midnight:   return UIColor(r: 240, g: 237, b: 248)
        case .ember:      return UIColor(r: 247, g: 237, b: 229)
        case .slate:      return UIColor(r: 240, g: 244, b: 250)
        }
    }
    var cardLight: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 229, g: 223, b: 209)
        case .ocean:      return UIColor(r: 214, g: 237, b: 242)
        case .midnight:   return UIColor(r: 228, g: 223, b: 243)
        case .ember:      return UIColor(r: 239, g: 224, b: 212)
        case .slate:      return UIColor(r: 226, g: 234, b: 248)
        }
    }
    var borderLight: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 199, g: 201, b: 177)
        case .ocean:      return UIColor(r: 168, g: 213, b: 223)
        case .midnight:   return UIColor(r: 197, g: 187, b: 223)
        case .ember:      return UIColor(r: 212, g: 186, b: 160)
        case .slate:      return UIColor(r: 184, g: 204, b: 232)
        }
    }
    var mutedLight: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 138, g: 132, b: 112)
        case .ocean:      return UIColor(r: 107, g: 151, b: 165)
        case .midnight:   return UIColor(r: 136, g: 120, b: 176)
        case .ember:      return UIColor(r: 154, g: 122, b: 104)
        case .slate:      return UIColor(r: 122, g: 146, b: 175)
        }
    }
    var textLight: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 26,  g: 26,  b: 20)
        case .ocean:      return UIColor(r: 13,  g: 43,  b: 51)
        case .midnight:   return UIColor(r: 26,  g: 19,  b: 48)
        case .ember:      return UIColor(r: 30,  g: 15,  b: 8)
        case .slate:      return UIColor(r: 13,  g: 24,  b: 38)
        }
    }

    // MARK: - Dark mode UIColors

    var accentDark: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 125, g: 160, b: 58)
        case .ocean:      return UIColor(r: 43,  g: 192, b: 208)
        case .midnight:   return UIColor(r: 155, g: 126, b: 232)
        case .ember:      return UIColor(r: 232, g: 106, b: 56)
        case .slate:      return UIColor(r: 91,  g: 138, b: 232)
        }
    }
    var bgDark: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 28,  g: 26,  b: 20)
        case .ocean:      return UIColor(r: 9,   g: 24,  b: 30)
        case .midnight:   return UIColor(r: 15,  g: 12,  b: 26)
        case .ember:      return UIColor(r: 26,  g: 14,  b: 9)
        case .slate:      return UIColor(r: 9,   g: 17,  b: 29)
        }
    }
    var cardDark: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 37,  g: 34,  b: 25)
        case .ocean:      return UIColor(r: 15,  g: 34,  b: 41)
        case .midnight:   return UIColor(r: 23,  g: 19,  b: 42)
        case .ember:      return UIColor(r: 38,  g: 21,  b: 16)
        case .slate:      return UIColor(r: 16,  g: 26,  b: 43)
        }
    }
    var borderDark: UIColor {
        switch self {
        case .fieldNotes: return UIColor(r: 58,  g: 54,  b: 42)
        case .ocean:      return UIColor(r: 26,  g: 58,  b: 70)
        case .midnight:   return UIColor(r: 42,  g: 34,  b: 69)
        case .ember:      return UIColor(r: 61,  g: 34,  b: 21)
        case .slate:      return UIColor(r: 28,  g: 45,  b: 69)
        }
    }
    var mutedDark: UIColor {
        // Muted text is the same as light in all themes
        mutedLight
    }
    var textDark: UIColor {
        // Text in dark = light bg color (inverted)
        bgLight
    }

    // MARK: - Preview swatches (always light-mode colors for wizard display)

    var previewBg:     Color { Color(bgLight) }
    var previewCard:   Color { Color(cardLight) }
    var previewAccent: Color { Color(accentLight) }
    var previewText:   Color { Color(textLight) }
    var previewMuted:  Color { Color(mutedLight) }
    var previewBorder: Color { Color(borderLight) }

    // MARK: - Active palette helper

    static var current: ThemePalette {
        let key = UserDefaults.standard.string(forKey: "colorTheme") ?? ThemePalette.fieldNotes.rawValue
        return ThemePalette(rawValue: key) ?? .fieldNotes
    }
}

// MARK: - UIColor convenience

private extension UIColor {
    convenience init(r: Int, g: Int, b: Int) {
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}

import Foundation
import SwiftUI
import UIKit

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
//
// All semantic Color tokens resolve through `ThemePalette.current`
// inside a `UIColor { tc in … }` dynamic provider. The closure runs
// every time UIKit/SwiftUI resolves the color (each render pass), so
// flipping the `colorTheme` AppStorage value and forcing a re-render
// (via `.id(colorTheme + appTheme)` on the root view) picks up the
// new palette without any view-level wiring.
//
// Token names are kept (`emerald`, `slateBackground`, etc.) for
// compatibility with hundreds of call sites — they're now palette
// roles, not literal colors. `fieldNotesAlert` stays a fixed red so
// destructive UI always reads as a warning regardless of theme.

extension Color {
    // MARK: Accent — palette.accentLight / accentDark
    static let emerald = Color(UIColor { tc in
        let p = ThemePalette.current
        return tc.userInterfaceStyle == .dark ? p.accentDark : p.accentLight
    })

    // MARK: Backgrounds
    /// Main page background.
    static let slateBackground = Color(UIColor { tc in
        let p = ThemePalette.current
        return tc.userInterfaceStyle == .dark ? p.bgDark : p.bgLight
    })
    /// Card / surface background.
    static let slateCard = Color(UIColor { tc in
        let p = ThemePalette.current
        return tc.userInterfaceStyle == .dark ? p.cardDark : p.cardLight
    })
    /// Hairline border between surfaces.
    static let slateBorder = Color(UIColor { tc in
        let p = ThemePalette.current
        return tc.userInterfaceStyle == .dark ? p.borderDark : p.borderLight
    })

    // MARK: Text
    /// Muted / secondary text.
    static let slateText = Color(UIColor { tc in
        let p = ThemePalette.current
        return tc.userInterfaceStyle == .dark ? p.mutedDark : p.mutedLight
    })
    /// Primary text.
    static let ink = Color(UIColor { tc in
        let p = ThemePalette.current
        return tc.userInterfaceStyle == .dark ? p.textDark : p.textLight
    })

    // MARK: Surface tones
    /// "Paper" — used as the foreground on accent-filled buttons. Maps
    /// to the palette's light-mode background so contrast against the
    /// accent stays correct in both light and dark themes (the accent
    /// itself was tuned against `bgLight`).
    static let paper = Color(UIColor { _ in
        ThemePalette.current.bgLight
    })
    /// Subtle accent-tinted surface (used for selected-row chrome,
    /// goal-card icon backgrounds, etc.). Derived from the accent at
    /// low alpha so it picks up the active theme automatically.
    static let oliveTint = Color(UIColor { tc in
        let p = ThemePalette.current
        let base = tc.userInterfaceStyle == .dark ? p.accentDark : p.accentLight
        return base.withAlphaComponent(0.18)
    })

    // MARK: Fixed alert red — intentionally NOT palette-driven.
    /// Destructive / warning surfaces should always read as red so
    /// users can recognise them regardless of which theme is active.
    static let fieldNotesAlert = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 196/255, green:  84/255, blue:  60/255, alpha: 1) // #C4543C
            : UIColor(red: 139/255, green:  58/255, blue:  42/255, alpha: 1) // #8B3A2A
    })
}

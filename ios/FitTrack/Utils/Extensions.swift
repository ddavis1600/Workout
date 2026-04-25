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
// Field Notes palette — adaptive light (paper/ink/olive) + dark (warm dark)

extension Color {
    // MARK: Accent — olive #556B2F / #7DA03A (brighter for dark bg)
    static let emerald = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 125/255, green: 160/255, blue:  58/255, alpha: 1) // #7DA03A
            : UIColor(red:  85/255, green: 107/255, blue:  47/255, alpha: 1) // #556B2F
    })

    // MARK: Backgrounds
    // Main page background: paper #EDE8DC / dark warm #1C1A14
    static let slateBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red:  28/255, green:  26/255, blue:  20/255, alpha: 1) // #1C1A14
            : UIColor(red: 237/255, green: 232/255, blue: 220/255, alpha: 1) // #EDE8DC
    })
    // Card background: paper2 #E5DFD1 / dark card #252219
    static let slateCard = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red:  37/255, green:  34/255, blue:  25/255, alpha: 1) // #252219
            : UIColor(red: 229/255, green: 223/255, blue: 209/255, alpha: 1) // #E5DFD1
    })
    // Border: olive rule #C7C9B1 / dark border #3A362A
    static let slateBorder = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red:  58/255, green:  54/255, blue:  42/255, alpha: 1) // #3A362A
            : UIColor(red: 199/255, green: 201/255, blue: 177/255, alpha: 1) // #C7C9B1
    })

    // MARK: Text
    // Muted text: #8A8470 — same in both modes (readable on both backgrounds)
    static let slateText = Color(red: 138/255, green: 132/255, blue: 112/255)
    // Primary text: ink #1A1A14 / paper #EDE8DC
    static let ink = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 237/255, green: 232/255, blue: 220/255, alpha: 1) // #EDE8DC
            : UIColor(red:  26/255, green:  26/255, blue:  20/255, alpha: 1) // #1A1A14
    })

    // MARK: Fixed tokens (not adaptive)
    // paper is always the warm off-white — used as text on olive-filled selected states
    static let paper = Color(red: 237/255, green: 232/255, blue: 220/255) // #EDE8DC
    // Olive tint surface: #D4DDB8 / dark olive tint #3D4A1E
    static let oliveTint = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red:  61/255, green:  74/255, blue:  30/255, alpha: 1) // #3D4A1E
            : UIColor(red: 212/255, green: 221/255, blue: 184/255, alpha: 1) // #D4DDB8
    })
    // Alert red #8B3A2A / #C4543C (brighter on dark)
    static let fieldNotesAlert = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 196/255, green:  84/255, blue:  60/255, alpha: 1) // #C4543C
            : UIColor(red: 139/255, green:  58/255, blue:  42/255, alpha: 1) // #8B3A2A
    })
}

// MARK: - Destructive-confirm helper

extension View {
    /// Attaches a confirmation dialog gated on a Bool. Pattern:
    ///
    ///     @State private var showingDelete = false
    ///     Button(role: .destructive) { showingDelete = true } label: {
    ///         Label("Delete", systemImage: "trash")
    ///     }
    ///     .destructiveConfirm(
    ///         "Delete entry?",
    ///         isPresented: $showingDelete,
    ///         message: "This can't be undone."
    ///     ) { viewModel.deleteEntry(entry) }
    ///
    /// JournalView shipped this same shape with `.alert(...)`; this
    /// modifier standardizes on `.confirmationDialog` across the app
    /// per AUDIT H5 (shorter UX, less heavyweight than alert).
    func destructiveConfirm(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        confirmLabel: String = "Delete",
        action: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button(confirmLabel, role: .destructive, action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            if let message { Text(message) }
        }
    }
}

// MARK: - Keyboard Done toolbar

extension View {
    /// Adds a `Done` button to the keyboard's accessory toolbar that
    /// dismisses any active text field. Use on screens with `.numberPad`
    /// or `.decimalPad` keyboards — those keyboards have no Return key,
    /// so without this the user gets stuck after typing into them
    /// (tapping outside in a List/Form is unreliable on iOS 17+).
    ///
    /// HeartRateView introduced the original pattern with a `@FocusState`
    /// + per-field binding; this modifier sidesteps that plumbing by
    /// resigning the first responder globally via UIResponder. Same UX,
    /// one-line drop-in for any screen.
    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbarModifier())
    }
}

private struct KeyboardDoneToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .foregroundStyle(Color.emerald)
                .fontWeight(.semibold)
            }
        }
    }
}

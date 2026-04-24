import Foundation
import SwiftUI
import UIKit

// MARK: - Keyboard Dismiss Helpers
// `.numberPad` / `.decimalPad` have no Return / Done key. Without a keyboard
// accessory toolbar the user has no way to dismiss the keyboard short of
// scrolling it off. HeartRateView fixed this first; this modifier ships the
// same pattern everywhere in one line so future forms get it for free.
//
// Usage:
//   ScrollView { /* fields */ }
//     .keyboardDoneToolbar()
//
// Apply to the enclosing container (NavigationStack child, Form, ScrollView)
// — SwiftUI shows the accessory only while a keyboard is visible.

extension View {
    /// Adds a "Done" button above the keyboard that dismisses any focused field.
    /// Stateless — uses `resignFirstResponder` so no `@FocusState` plumbing is
    /// required at the call site.
    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbar())
    }
}

private struct KeyboardDoneToolbar: ViewModifier {
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

// MARK: - Destructive Confirm Helper
// Matches JournalView's existing `.alert(...)` confirmation convention so every
// destructive action in the app reads the same way. Each call supplies a title,
// an optional descriptive message, and a closure to run on confirm.
//
// Usage:
//   @State private var pendingDelete: Habit?
//   ...
//   .confirmDestructive(
//       item: $pendingDelete,
//       title: "Delete habit?",
//       message: { habit in "Removes \(habit.completions?.count ?? 0) check-ins." },
//       onConfirm: { habit in viewModel.delete(habit) }
//   )

extension View {
    /// Presents a standard destructive-confirm `.alert` driven by an optional
    /// state item. The alert appears while `item` is non-nil and clears on
    /// either button. Message is evaluated against the pending item so the
    /// copy can include item-specific detail (e.g. completion count).
    func confirmDestructive<Item>(
        item: Binding<Item?>,
        title: String,
        message: @escaping (Item) -> String,
        confirmLabel: String = "Delete",
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        modifier(
            ConfirmDestructiveModifier(
                item: item,
                title: title,
                message: message,
                confirmLabel: confirmLabel,
                onConfirm: onConfirm
            )
        )
    }
}

private struct ConfirmDestructiveModifier<Item>: ViewModifier {
    @Binding var item: Item?
    let title: String
    let message: (Item) -> String
    let confirmLabel: String
    let onConfirm: (Item) -> Void

    func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: Binding(
                get: { item != nil },
                set: { if !$0 { item = nil } }
            ),
            presenting: item
        ) { pending in
            Button(confirmLabel, role: .destructive) {
                onConfirm(pending)
                item = nil
            }
            Button("Cancel", role: .cancel) {
                item = nil
            }
        } message: { pending in
            Text(message(pending))
        }
    }
}

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

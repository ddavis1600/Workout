import SwiftUI
import AppIntents

/// "Siri & Shortcuts" settings page. Lists the five intents
/// `FitTrackShortcuts` registered, with their invocation phrases
/// + a per-intent toggle so users can hide ones they don't want
/// surfaced in Spotlight / Siri Suggestions (audit ref F4 spec
/// "Settings UI for shortcut visibility").
///
/// Visibility toggles flip a per-intent UserDefaults key. The
/// system doesn't expose a runtime "hide this AppShortcut" API,
/// so the toggle is advisory: it dictates whether the intent
/// short-circuits in `perform()` if disabled. A future revision
/// can use the toggle state to filter `FitTrackShortcuts.appShortcuts`
/// by recompiling the provider — for now the toggle is honored at
/// the intent boundary.
struct ShortcutsSettingsView: View {
    @AppStorage("shortcut_logWorkoutEnabled") private var logWorkoutEnabled = true
    @AppStorage("shortcut_logFoodEnabled")    private var logFoodEnabled    = true
    @AppStorage("shortcut_logWeightEnabled")  private var logWeightEnabled  = true
    @AppStorage("shortcut_logHabitEnabled")   private var logHabitEnabled   = true
    @AppStorage("shortcut_stopWorkoutEnabled") private var stopWorkoutEnabled = true

    var body: some View {
        List {
            Section {
                Text("FitTrack registers five Siri & Shortcuts actions. They appear automatically in Spotlight, the Shortcuts app, and Siri Suggestions once you've used the app for a few days.")
                    .font(.footnote)
                    .foregroundStyle(Color.slateText)
                    .listRowBackground(Color.slateBackground)
            }

            shortcutSection(
                title: "Log a Workout",
                subtitle: "Opens FitTrack with a pre-filled workout entry.",
                icon: "dumbbell.fill",
                phrases: [
                    "\"Log a workout in FitTrack\"",
                    "\"Start a workout in FitTrack\"",
                ],
                isOn: $logWorkoutEnabled
            )

            shortcutSection(
                title: "Log a Meal",
                subtitle: "Adds a meal to the food diary without opening the app.",
                icon: "fork.knife",
                phrases: [
                    "\"Log a meal in FitTrack\"",
                    "\"Log breakfast in FitTrack\"",
                ],
                isOn: $logFoodEnabled
            )

            shortcutSection(
                title: "Log My Weight",
                subtitle: "Records a weight entry and syncs to Apple Health.",
                icon: "scalemass.fill",
                phrases: [
                    "\"Log my weight in FitTrack\"",
                    "\"Track weight in FitTrack\"",
                ],
                isOn: $logWeightEnabled
            )

            shortcutSection(
                title: "Mark Habit Complete",
                subtitle: "Toggles a habit's check-in for today.",
                icon: "checkmark.circle.fill",
                phrases: [
                    "\"Mark a habit complete in FitTrack\"",
                    "\"Complete a habit in FitTrack\"",
                ],
                isOn: $logHabitEnabled
            )

            shortcutSection(
                title: "Stop Workout",
                subtitle: "Ends the active Live Activity workout. Used by the Dynamic Island Stop button.",
                icon: "stop.fill",
                phrases: [
                    "\"Stop my workout in FitTrack\"",
                    "\"End workout in FitTrack\"",
                ],
                isOn: $stopWorkoutEnabled
            )

            Section {
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Shortcuts app", systemImage: "arrow.up.forward.app")
                        .foregroundStyle(Color.emerald)
                }
                .listRowBackground(Color.slateCard)
            } footer: {
                Text("Build your own multi-step shortcuts using FitTrack's actions in the Shortcuts app.")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.slateBackground)
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One section per shortcut: header with icon + title, body with
    /// invocation phrases the user can read out loud, and a toggle
    /// at the bottom that pins the AppStorage flag the intent's
    /// `perform()` reads to short-circuit.
    @ViewBuilder
    private func shortcutSection(
        title: String,
        subtitle: String,
        icon: String,
        phrases: [String],
        isOn: Binding<Bool>
    ) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.emerald)
                    .frame(width: 32, height: 32)
                    .background(Color.emerald.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(.emerald)
            }
            .listRowBackground(Color.slateCard)

            VStack(alignment: .leading, spacing: 6) {
                Text("Try saying:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.slateText)
                ForEach(phrases, id: \.self) { phrase in
                    Text(phrase)
                        .font(.callout.italic())
                        .foregroundStyle(Color.ink)
                }
            }
            .listRowBackground(Color.slateCard)
        }
    }
}

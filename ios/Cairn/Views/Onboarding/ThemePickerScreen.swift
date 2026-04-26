import SwiftUI
import UIKit

/// Pre-onboarding theme picker (audit ref F-theme-pre).
///
/// Runs as the very first view on a fresh install — BEFORE
/// `OnboardingFlow` mounts. The user sees the app name, picks a
/// brightness mode + colour palette, and taps Continue. Only then
/// does the multi-step wizard start.
///
/// Why a separate screen instead of a step inside the wizard:
///
/// SwiftUI views with palette-aware colour tokens need a parent
/// rebuild to repaint the whole tree on palette change (the tokens
/// resolve `ThemePalette.current` at render time, and SwiftUI only
/// re-resolves them when the subtree re-renders). The previous
/// attempt placed `.id(colorTheme + appTheme)` on the WindowGroup
/// root so the swap was visible everywhere — which destroyed
/// `OnboardingFlow`'s `@State` (current step, profile fields, …)
/// every time the user tapped a swatch. The wizard kept restarting.
///
/// The fix: lock the theme in BEFORE any state-bearing view exists.
/// This screen has no persistent state of its own (just the
/// `@AppStorage` bindings), so taps freely re-render here without
/// affecting any wizard. The flag `hasCompletedPreOnboarding` gates
/// transition to `OnboardingFlow`, and from that point on the
/// wizard's `@State` is safe — palette changes during onboarding
/// don't happen, and changes from Settings happen against a fully
/// mounted ContentView (which has its own `.id(...)` tied to the
/// theme; rebuilding ContentView once is acceptable).
struct ThemePickerScreen: View {
    /// Called when the user taps Continue. The caller flips the
    /// `hasCompletedPreOnboarding` flag and switches to the next
    /// view. We don't own that flag here so the screen stays
    /// reusable (e.g. could be presented from Settings in the
    /// future as a "reset onboarding" affordance).
    let onContinue: () -> Void

    @AppStorage("appTheme")   private var appTheme   = "system"
    @AppStorage("colorTheme") private var colorTheme = "fieldNotes"

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                // Header — kept compact so the picker controls are
                // the visual focus.
                VStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(Color.emerald)
                    Text("Welcome to Cairn")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.ink)
                    Text("First, pick how you'd like the app to look.")
                        .font(.subheadline)
                        .foregroundStyle(Color.slateText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Brightness segmented — sits above palette so the
                // light/dark choice reads as the primary control,
                // matching the Settings layout.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mode")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.ink)
                    Picker("Mode", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 24)

                // Palette grid — 3 columns fits 5 palettes in two
                // rows on every iPhone width without crowding.
                VStack(alignment: .leading, spacing: 10) {
                    Text("Colour")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.ink)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                        ],
                        spacing: 14
                    ) {
                        ForEach(ThemePalette.allCases) { palette in
                            ThemeSwatchButton(
                                palette: palette,
                                isSelected: colorTheme == palette.rawValue
                            ) {
                                colorTheme = palette.rawValue
                                // Tactile confirmation — the live
                                // re-paint comes "for free" because
                                // this view re-renders when
                                // colorTheme changes (it's an
                                // @AppStorage we read above).
                                UIImpactFeedbackGenerator(style: .light)
                                    .impactOccurred()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Text("You can change all of this later in Settings.")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.emerald)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    ThemePickerScreen(onContinue: {})
}

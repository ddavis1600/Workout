import SwiftUI

struct OnboardingView: View {
    @AppStorage("colorTheme")             private var colorTheme      = "fieldNotes"
    @AppStorage("appTheme")               private var appTheme        = "system"
    @AppStorage("hasCompletedOnboarding") private var hasCompleted    = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPalette: ThemePalette = .fieldNotes

    private var isDark: Bool { colorScheme == .dark }
    private func accent(_ p: ThemePalette)  -> UIColor { isDark ? p.accentDark  : p.accentLight }
    private func bg(_ p: ThemePalette)      -> UIColor { isDark ? p.bgDark      : p.bgLight }
    private func card(_ p: ThemePalette)    -> UIColor { isDark ? p.cardDark    : p.cardLight }
    private func border(_ p: ThemePalette)  -> UIColor { isDark ? p.borderDark  : p.borderLight }
    private func muted(_ p: ThemePalette)   -> UIColor { isDark ? p.mutedDark   : p.mutedLight }
    private func text(_ p: ThemePalette)    -> UIColor { isDark ? p.textDark    : p.textLight }

    var body: some View {
        ZStack {
            Color(bg(selectedPalette)).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color(accent(selectedPalette)))
                        .padding(.bottom, 4)
                    Text("Welcome to FitTrack")
                        .font(.title.bold())
                        .foregroundStyle(Color(text(selectedPalette)))
                    Text("Pick a style that feels like you")
                        .font(.subheadline)
                        .foregroundStyle(Color(muted(selectedPalette)))
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                // Theme cards — horizontal pager
                TabView(selection: $selectedPalette) {
                    ForEach(ThemePalette.allCases) { palette in
                        ThemePreviewCard(palette: palette, isSelected: selectedPalette == palette, isDark: isDark)
                            .padding(.horizontal, 24)
                            .tag(palette)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 440)

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(ThemePalette.allCases) { palette in
                        Circle()
                            .fill(selectedPalette == palette
                                  ? Color(accent(selectedPalette))
                                  : Color(muted(selectedPalette)).opacity(0.4))
                            .frame(width: selectedPalette == palette ? 10 : 7,
                                   height: selectedPalette == palette ? 10 : 7)
                            .animation(.spring(response: 0.3), value: selectedPalette)
                    }
                }
                .padding(.top, 16)

                Spacer()

                // Brightness row
                VStack(spacing: 10) {
                    Text("Brightness")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(muted(selectedPalette)))

                    HStack(spacing: 0) {
                        ForEach([("sun.max.fill","Light","light"),
                                 ("circle.lefthalf.filled","System","system"),
                                 ("moon.fill","Dark","dark")], id: \.2) { icon, label, tag in
                            Button {
                                appTheme = tag
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                    Text(label)
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(appTheme == tag
                                                 ? Color(bg(selectedPalette))
                                                 : Color(muted(selectedPalette)))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(appTheme == tag
                                            ? Color(accent(selectedPalette))
                                            : Color.clear)
                                .animation(.easeInOut(duration: 0.15), value: appTheme)
                            }
                        }
                    }
                    .background(Color(card(selectedPalette)))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(border(selectedPalette)), lineWidth: 1))
                }
                .padding(.horizontal, 24)

                // Get Started button
                Button {
                    colorTheme = selectedPalette.rawValue
                    if UIApplication.shared.supportsAlternateIcons,
                       selectedPalette != .fieldNotes {
                        UIApplication.shared.setAlternateIconName("AppIcon-\(selectedPalette.rawValue)")
                    }
                    withAnimation { hasCompleted = true }
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(Color(bg(selectedPalette)))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(accent(selectedPalette)))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(appTheme == "dark" ? .dark : appTheme == "light" ? .light : nil)
        .onAppear {
            selectedPalette = ThemePalette(rawValue: colorTheme) ?? .fieldNotes
        }
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let palette: ThemePalette
    let isSelected: Bool
    let isDark: Bool

    private func accent() -> UIColor { isDark ? palette.accentDark  : palette.accentLight }
    private func bg()     -> UIColor { isDark ? palette.bgDark      : palette.bgLight }
    private func card()   -> UIColor { isDark ? palette.cardDark    : palette.cardLight }
    private func border() -> UIColor { isDark ? palette.borderDark  : palette.borderLight }
    private func muted()  -> UIColor { isDark ? palette.mutedDark   : palette.mutedLight }
    private func text()   -> UIColor { isDark ? palette.textDark    : palette.textLight }

    var body: some View {
        VStack(spacing: 0) {
            // Mini app mockup
            VStack(spacing: 0) {
                // Fake navigation bar
                HStack {
                    Text("Workouts")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(text()))
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(accent()))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(bg()))

                Divider().overlay(Color(border()))

                // Fake content
                VStack(spacing: 10) {
                    // Stat card row
                    HStack(spacing: 8) {
                        miniStatCard(label: "Workouts", value: "12")
                        miniStatCard(label: "Calories", value: "2,340")
                    }

                    // Fake list rows
                    ForEach(["Push Day", "Leg Day", "Pull Day"], id: \.self) { name in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(accent()))
                                .frame(width: 3, height: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(text()))
                                Text("4 exercises · 16 sets")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(muted()))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(muted()))
                        }
                        .padding(10)
                        .background(Color(card()))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(border()), lineWidth: 0.5))
                    }

                    // Fake progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Protein")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(muted()))
                            Spacer()
                            Text("142g / 180g")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(text()))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(border()))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(accent()))
                                    .frame(width: geo.size.width * 0.79, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(10)
                    .background(Color(card()))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(border()), lineWidth: 0.5))
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(bg()))

                // Fake tab bar
                Divider().overlay(Color(border()))
                HStack(spacing: 0) {
                    ForEach([("house.fill","Home"), ("dumbbell.fill","Workout"),
                             ("checkmark.circle","Habits"), ("scalemass","Weight"),
                             ("book.fill","Diary")], id: \.0) { icon, label in
                        VStack(spacing: 2) {
                            Image(systemName: icon)
                                .font(.system(size: 13))
                            Text(label)
                                .font(.system(size: 7, weight: .medium))
                        }
                        .foregroundStyle(label == "Workout"
                                         ? Color(accent())
                                         : Color(muted()))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                .background(Color(card()))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected
                            ? Color(accent())
                            : Color(border()),
                            lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: isSelected ? Color(accent()).opacity(0.3) : .clear,
                    radius: 12, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.0 : 0.97)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)

            // Name + tagline
            VStack(spacing: 4) {
                Text(palette.displayName)
                    .font(.headline)
                    .foregroundStyle(Color(text()))
                Text(palette.tagline)
                    .font(.caption)
                    .foregroundStyle(Color(muted()))
            }
            .padding(.top, 14)
        }
    }

    private func miniStatCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(accent()))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color(muted()))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(card()))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color(border()), lineWidth: 0.5))
    }
}

#Preview {
    OnboardingView()
}

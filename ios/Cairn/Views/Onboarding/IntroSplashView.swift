import SwiftUI

/// Brief launch splash: app icon rotates once, wordmark fades in, then
/// auto-dismisses. Rendered as an overlay in ContentView on every launch
/// (separate from the first-launch OnboardingView).
///
/// Total duration ≈ 2.5s. The caller sets its binding to false after
/// `Task.sleep(for: .seconds(2.5))` so we don't block the UI.
struct IntroSplashView: View {
    @State private var rotation: Double = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 16

    var body: some View {
        ZStack {
            // Opaque background so the tab bar and tab content don't
            // flash through during the splash.
            Color.slateBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("AppIconPreview")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(rotation))

                Text("FitTrack")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffset)
            }
        }
        .task {
            // Icon: scale in + one full rotation over 1.2s
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                iconScale = 1.0
            }
            withAnimation(.easeInOut(duration: 1.2)) {
                rotation = 360
            }
            // Wordmark: fades in with a slight upward slide, starting
            // after the icon's spin is underway.
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeOut(duration: 0.4)) {
                wordmarkOpacity = 1
                wordmarkOffset = 0
            }
        }
    }
}

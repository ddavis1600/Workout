import SwiftUI

// MARK: - Field Log Mark
// Logo rendered as native SwiftUI Canvas shapes — crisp at all sizes,
// rotation/blur/shadow applied by parent without rasterization artifacts.

struct FieldLogMark: View {
    var size: CGFloat = 120

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height

            // — Background: cream paper —
            let bg = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                          cornerRadius: w * 0.05)
            ctx.fill(bg, with: .color(Color(red: 232/255, green: 223/255, blue: 193/255)))

            let olive   = Color(red: 74/255,  green: 85/255,  blue: 48/255)
            let oliveHi = Color(red: 94/255,  green: 107/255, blue: 58/255)
            let ink     = Color(red: 61/255,  green: 72/255,  blue: 38/255)

            // — Outer border —
            let outerRect = CGRect(x: w*0.04, y: h*0.04,
                                   width: w*0.92, height: h*0.92)
            ctx.stroke(
                Path(roundedRect: outerRect, cornerRadius: w*0.03),
                with: .color(olive),
                style: StrokeStyle(lineWidth: w * 0.013))

            // — Inner border —
            let innerRect = CGRect(x: w*0.08, y: h*0.08,
                                   width: w*0.84, height: h*0.84)
            ctx.stroke(
                Path(roundedRect: innerRect, cornerRadius: w*0.02),
                with: .color(olive),
                style: StrokeStyle(lineWidth: w * 0.005))

            // — Subtle grid lines —
            for row in 1...4 {
                let y = h * (0.34 + Double(row) * 0.10)
                var p = Path(); p.move(to: .init(x: w*0.12, y: y))
                p.addLine(to: .init(x: w*0.88, y: y))
                ctx.stroke(p, with: .color(oliveHi.opacity(0.28)),
                            style: StrokeStyle(lineWidth: 0.5))
            }
            for col in 1...3 {
                let x = w * (0.22 + Double(col) * 0.19)
                var p = Path(); p.move(to: .init(x: x, y: h*0.24))
                p.addLine(to: .init(x: x, y: h*0.80))
                ctx.stroke(p, with: .color(oliveHi.opacity(0.28)),
                            style: StrokeStyle(lineWidth: 0.5))
            }

            // — Axes —
            let axisWidth = w * 0.009
            var yAxis = Path()
            yAxis.move(to: .init(x: w*0.18, y: h*0.22))
            yAxis.addLine(to: .init(x: w*0.18, y: h*0.80))
            ctx.stroke(yAxis, with: .color(olive),
                        style: StrokeStyle(lineWidth: axisWidth, lineCap: .round))

            var xAxis = Path()
            xAxis.move(to: .init(x: w*0.18, y: h*0.80))
            xAxis.addLine(to: .init(x: w*0.88, y: h*0.80))
            ctx.stroke(xAxis, with: .color(olive),
                        style: StrokeStyle(lineWidth: axisWidth, lineCap: .round))

            // — Rising line —
            let pts: [CGPoint] = [
                .init(x: w*0.23, y: h*0.74),
                .init(x: w*0.37, y: h*0.66),
                .init(x: w*0.51, y: h*0.54),
                .init(x: w*0.65, y: h*0.40),
                .init(x: w*0.80, y: h*0.26),
            ]
            var line = Path()
            line.move(to: pts[0])
            for pt in pts.dropFirst() { line.addLine(to: pt) }
            ctx.stroke(line, with: .color(ink),
                        style: StrokeStyle(lineWidth: w*0.028, lineCap: .round, lineJoin: .round))

            // — Arrow tip —
            var arrow = Path()
            arrow.move(to: .init(x: w*0.71, y: h*0.24))
            arrow.addLine(to: pts[4])
            arrow.addLine(to: .init(x: w*0.78, y: h*0.34))
            ctx.stroke(arrow, with: .color(ink),
                        style: StrokeStyle(lineWidth: w*0.028, lineCap: .round, lineJoin: .round))

            // — Data dots —
            let r = w * 0.030
            for pt in pts {
                ctx.fill(
                    Path(ellipseIn: .init(x: pt.x - r, y: pt.y - r, width: r*2, height: r*2)),
                    with: .color(ink))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Launch Animation View

struct LaunchAnimationView: View {
    let onFinished: () -> Void

    @State private var scale:       CGFloat = 0.85
    @State private var rotation:    Double  = -540
    @State private var offsetY:     CGFloat = -64
    @State private var opacity:     Double  = 0
    @State private var blur:        CGFloat = 8
    @State private var glowOpacity: Double  = 0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Light/dark-aware radial gradient background
            RadialGradient(
                gradient: Gradient(colors: colorScheme == .dark
                    ? [Color(red: 61/255,  green: 74/255,  blue: 30/255).opacity(0.35),
                       Color(red: 28/255,  green: 26/255,  blue: 20/255)]
                    : [Color(red: 212/255, green: 221/255, blue: 184/255).opacity(0.55),
                       Color(red: 232/255, green: 223/255, blue: 193/255)]
                ),
                center: .center,
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()

            ZStack {
                // Glow halo — blurred copy behind the mark
                FieldLogMark(size: 128)
                    .blur(radius: 20)
                    .opacity(glowOpacity)
                    .scaleEffect(1.18)

                // Main mark
                FieldLogMark(size: 128)
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(y: offsetY)
            .opacity(opacity)
            .blur(radius: blur)
        }
        .onAppear { animate() }
    }

    private func animate() {
        // Main entry — custom cubic Bézier (0.2, 0.9, 0.25, 1.0) over 0.85 s
        withAnimation(.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.85)) {
            scale    = 1.0
            rotation = 0
            offsetY  = 0
            opacity  = 1.0
        }

        // Blur dissolves faster — 0.55 s
        withAnimation(.easeOut(duration: 0.55)) {
            blur = 0
        }

        // Glow pulse on settle — spring kick after entry lands (~0.75 s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                glowOpacity = 0.42
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.easeOut(duration: 0.42)) {
                    glowOpacity = 0
                }
            }
        }

        // Cross-fade to app at 1.6 s total
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.35)) {
                onFinished()
            }
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            ContentView()
                .opacity(showLaunch ? 0 : 1)

            if showLaunch {
                LaunchAnimationView {
                    showLaunch = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LaunchAnimationView { }
}

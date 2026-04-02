import SwiftUI

struct MacroRing: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return current / target
    }

    private var ringColor: Color {
        current > target ? .red : color
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(animatedProgress, 1.0))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("/ \(Int(target))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.slateText)
                }
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.slateText)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: current) {
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = progress
            }
        }
        .onChange(of: target) {
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = progress
            }
        }
    }
}

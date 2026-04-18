import SwiftUI

struct MacroProgressBar: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return current / target
    }

    private var barColor: Color {
        if progress > 1.0 {
            return .red
        } else if progress >= 0.8 {
            return .yellow
        } else {
            return color
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(Int(current))\(unit) / \(Int(target))\(unit)")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: min(geo.size.width * progress, geo.size.width), height: 8)
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

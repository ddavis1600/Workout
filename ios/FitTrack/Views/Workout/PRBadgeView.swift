import SwiftUI

struct PRBadgeView: View {
    let prTypes: [PRType]

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)

            Text(prTypes.map(\.rawValue).joined(separator: " · "))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

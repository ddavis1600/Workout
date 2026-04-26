import SwiftUI

// Collapsible tier wrapper. In Phase A only the Core Vitals tier ever
// has content; Fitness and Wellness pass `hasContent: false` so they
// render as a header-only placeholder — the structure that Phase B
// will fill in. Per-tier expand/collapse state persists across runs.
struct TierSection<Content: View>: View {
    let tier: HealthMetric.Tier
    let icon: String
    let hasContent: Bool
    @ViewBuilder let content: () -> Content

    @AppStorage private var expanded: Bool

    init(
        tier: HealthMetric.Tier,
        icon: String,
        hasContent: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tier = tier
        self.icon = icon
        self.hasContent = hasContent
        self.content = content
        // Default: Core Vitals expanded; Fitness/Wellness collapsed.
        self._expanded = AppStorage(
            wrappedValue: tier == .coreVitals,
            "healthDash.section.\(tier.rawValue)"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if expanded && hasContent {
                content()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(hasContent ? Color.emerald : Color.slateText)
                .frame(width: 24)
            Text(tier.label)
                .font(.headline)
                .foregroundStyle(hasContent ? .primary : .secondary)
            Spacer()
            if hasContent {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

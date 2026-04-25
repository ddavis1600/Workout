import SwiftUI
import SwiftData

// One Tier 1 card — label, big value, unit. The sparkline area is a
// placeholder rectangle in this commit; the per-metric Charts variants
// land in the next commit and replace `sparklinePlaceholder` per
// `summary.metric.chart`. Tap → MetricDetailSheet.
struct MetricCard: View {
    let summary: MetricSummary
    @State private var showingDetail = false

    // Weight is the only Phase A metric that re-formats to user pref;
    // the others use static units. Reads UserProfile via SwiftData
    // since `unitSystem` lives on the @Model, not UserDefaults.
    @Query private var profiles: [UserProfile]

    var body: some View {
        Button { showingDetail = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                header
                value
                sparklinePlaceholder
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.slateCard)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            MetricDetailSheet(summary: summary)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: summary.metric.icon)
                .foregroundStyle(Color.emerald)
            Text(summary.metric.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var value: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(formattedValue)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(displayUnit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sparklinePlaceholder: some View {
        Rectangle()
            .fill(Color.slateBorder.opacity(0.25))
            .frame(height: 40)
            .cornerRadius(4)
    }

    private var unitSystem: String {
        profiles.first?.unitSystem ?? "imperial"
    }

    private var displayUnit: String {
        if summary.metric.id == "weight" {
            return unitSystem == "metric" ? "kg" : "lb"
        }
        return summary.metric.unit
    }

    private var formattedValue: String {
        guard let v = summary.latest?.value else { return "—" }
        switch summary.metric.id {
        case "sleep":
            let hours = Int(v)
            let minutes = Int((v - Double(hours)) * 60)
            return "\(hours)h \(minutes)m"
        case "restingHR":
            return "\(Int(v.rounded()))"
        case "steps":
            return v.formatted(.number)
        case "weight":
            // Service returns kg; convert when user pref is imperial.
            let display = unitSystem == "metric" ? v : v * 2.20462
            return String(format: "%.1f", display)
        default:
            return v.formatted(.number)
        }
    }
}

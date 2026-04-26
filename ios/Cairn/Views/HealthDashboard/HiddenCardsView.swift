import SwiftUI

/// Settings → Health Dashboard → Hidden Cards.
///
/// Lists every metric the user has hidden from the dashboard
/// (via Edit mode's eye-slash button) and provides a one-tap
/// "Show" affordance that removes it from the hidden set. Empty
/// state when nothing is hidden — keeps the surface honest
/// rather than promising features.
struct HiddenCardsView: View {
    @AppStorage(DashboardCustomization.hiddenKey)
    private var hiddenCSV: String = ""

    private var hiddenIDs: [String] {
        DashboardCustomization.decode(hiddenCSV)
    }

    private var hiddenMetrics: [HealthMetric] {
        let set = Set(hiddenIDs)
        // Render in catalog order so the list reads consistently
        // regardless of when each card was hidden.
        return HealthMetric.all.filter { set.contains($0.id) }
    }

    var body: some View {
        List {
            if hiddenMetrics.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(.secondary)
                        Text("No hidden cards. Use the dashboard's Edit button to hide cards you don't want to see.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .listRowBackground(Color.slateCard)
                }
            } else {
                Section {
                    ForEach(hiddenMetrics) { metric in
                        HStack(spacing: 12) {
                            Image(systemName: metric.icon)
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.label)
                                    .foregroundColor(Color.ink)
                                Text(metric.tier.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Show") {
                                show(metric)
                            }
                            .buttonStyle(.bordered)
                            .tint(.emerald)
                        }
                        .listRowBackground(Color.slateCard)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.slateBackground)
        .navigationTitle("Hidden Cards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func show(_ metric: HealthMetric) {
        var ids = Set(hiddenIDs)
        ids.remove(metric.id)
        hiddenCSV = DashboardCustomization.encode(Array(ids).sorted())
    }
}

#Preview {
    NavigationStack { HiddenCardsView() }
}

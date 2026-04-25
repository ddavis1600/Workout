import SwiftUI

// Phase A placeholder. Phase B replaces this with the per-metric
// rich detail (full Swift Chart, time-range picker, sample history
// list). The card's tap target stays here through the transition so
// no view-call sites change.
struct MetricDetailSheet: View {
    let summary: MetricSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: summary.metric.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.emerald)
                Text(summary.metric.label)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Detail view coming in Phase B")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.slateBackground)
            .navigationTitle(summary.metric.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

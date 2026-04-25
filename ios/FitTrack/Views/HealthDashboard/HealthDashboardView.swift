import SwiftUI

// Phase A entry-point view. The tier sections, metric cards, and chart
// rendering land in subsequent commits; this commit wires the tab into
// ContentView and stands up the auth + refresh lifecycle so the rest
// of the dashboard can layer on without changing the entry point.
struct HealthDashboardView: View {
    private let service = HealthDashboardService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Health dashboard")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Color.slateBackground)
            .navigationTitle("Health")
            .task {
                await service.requestAuthorizationIfNeeded()
                await service.refreshIfStale()
            }
        }
    }
}

#Preview {
    HealthDashboardView()
}

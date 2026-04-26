import SwiftUI

// Phase A entry-point. Renders the three tier sections; Tier 1 holds
// the four MVP metric cards (sleep, resting HR, steps, weight),
// Tiers 2/3 are header-only placeholders for Phase B.
//
// Empty-card policy: cards self-hide when their MetricSummary lacks
// a latest sample. On the very first launch — before HK auth has been
// requested — Tier 1 shows a single AuthHandshakeCard that fires the
// batched authorization. After auth has been requested at least once,
// the strict hide-when-no-data rule applies (no lock CTAs, no nags).
struct HealthDashboardView: View {
    private let service = HealthDashboardService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    coreVitalsSection
                    fitnessSection
                    wellnessSection
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.slateBackground)
            .navigationTitle("Health")
            .task {
                // Don't auto-fire requestAuthorizationIfNeeded on appear.
                // HKHealthStore can raise an uncatchable Objective-C NSException
                // ("Authorization is disallowed for sharing") that bypasses
                // Swift's try/catch and crashes the app before the user gets a
                // chance to grant — observed reliably on iOS 18 simulators. The
                // AuthHandshakeCard's Connect button is the sole user-initiated
                // auth trigger; refreshIfStale just re-pulls cached summaries.
                await service.refreshIfStale()
            }
        }
    }

    // MARK: Tier 1 — Core Vitals

    private var coreVitalsSection: some View {
        TierSection(tier: .coreVitals, icon: "cross.case.fill", hasContent: tier1HasContent) {
            VStack(spacing: 12) {
                if shouldShowAuthHandshake {
                    AuthHandshakeCard {
                        Task {
                            await service.requestAuthorizationIfNeeded()
                            await service.refresh()
                        }
                    }
                }
                ForEach(coreVitalsCards) { summary in
                    MetricCard(summary: summary)
                }
            }
        }
    }

    // MARK: Tier 2 — Fitness

    private var fitnessSection: some View {
        // Tier 2 is "real" once any of its cards land — even with zero
        // populated cards we still show the header (collapsible) plus
        // an empty-state row, so the user knows the section exists and
        // why it's bare. Only when auth has never been requested AND
        // Tier 1 also has nothing do we suppress the section entirely;
        // that keeps the first-launch experience focused on the
        // Core Vitals handshake.
        TierSection(
            tier: .fitness,
            icon: "figure.run",
            hasContent: tier2HasAnyCardsOrAuth
        ) {
            VStack(spacing: 12) {
                if fitnessCards.isEmpty {
                    EmptyTierMessage(
                        text: "No Fitness data yet. Wear your Apple Watch and these cards will fill in automatically."
                    )
                } else {
                    ForEach(fitnessCards) { summary in
                        MetricCard(summary: summary)
                    }
                }
            }
        }
    }

    private var wellnessSection: some View {
        // Tier 3 is still a Phase C placeholder. Same empty-message
        // pattern as Tier 2 will apply when its cards land.
        TierSection(tier: .wellness, icon: "leaf.fill", hasContent: false) { EmptyView() }
    }

    // MARK: Filtering

    private var coreVitalsCards: [MetricSummary] {
        HealthMetric.all
            .filter { $0.tier == .coreVitals }
            .compactMap { service.summaries[$0.id] }
            .filter { $0.hasData }
    }

    private var fitnessCards: [MetricSummary] {
        HealthMetric.all
            .filter { $0.tier == .fitness }
            .compactMap { service.summaries[$0.id] }
            .filter { $0.hasData }
    }

    /// Tier 2 should render its header + content (or empty-state
    /// message) once auth has been requested at least once OR any
    /// fitness card has data. Until then, leave it as a flat
    /// placeholder so the dashboard doesn't sprawl on first launch.
    private var tier2HasAnyCardsOrAuth: Bool {
        service.hasRequestedAuth || !fitnessCards.isEmpty
    }

    private var shouldShowAuthHandshake: Bool {
        // Show only when we've never asked AND no metric has any data.
        // Once auth has been asked once (granted or denied), the strict
        // hide-when-no-data rule takes over.
        !service.hasRequestedAuth && coreVitalsCards.isEmpty
    }

    private var tier1HasContent: Bool {
        shouldShowAuthHandshake || !coreVitalsCards.isEmpty
    }
}

// MARK: - Auth handshake card

// First-launch placeholder. Once `hasRequestedDashboardAuth` is set,
// it never appears again — even on deny. The user explicitly opted out
// of lock-CTA / re-prompt nags.
private struct AuthHandshakeCard: View {
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.emerald)
            Text("Connect Apple Health")
                .font(.headline)
            Text("See your sleep, resting heart rate, steps, and weight at a glance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onConnect) {
                Text("Connect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.emerald)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.slateCard)
        .cornerRadius(12)
    }
}

// MARK: - Empty-tier message

/// Single-line subdued row used inside an expanded tier when zero
/// of its cards have data. Distinct from the auth-handshake card
/// (which is Tier 1 only, and only on first launch).
private struct EmptyTierMessage: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.slateCard.opacity(0.5))
        .cornerRadius(10)
    }
}

#Preview {
    HealthDashboardView()
}

import SwiftUI

// Health Dashboard entry point — three tier sections with the
// hide-when-no-data policy from Phase A and per-user reorder /
// hide customization from Phase C.
//
// Customization model:
// - Edit toolbar button toggles `editing`. In editing mode each
//   visible card grows a chevron-up / chevron-down / hide trio
//   in its trailing region, plus a faint reorder background to
//   signal the mode switch. Tap chevrons to reorder within the
//   tier (saved to `dashboard.cardOrder.<tier>`); tap the eye-
//   slash to hide (saved to `dashboard.hiddenCards`).
// - Hidden cards drop out of every tier list immediately and
//   reappear in Settings → Hidden cards, where they can be
//   un-hidden one tap.
//
// On the first launch — before HK auth has been requested —
// Tier 1 shows a single AuthHandshakeCard that fires the batched
// authorization. After auth has been requested at least once,
// the strict hide-when-no-data rule applies.
struct HealthDashboardView: View {
    private let service = HealthDashboardService.shared

    @State private var editing: Bool = false

    @AppStorage(DashboardCustomization.hiddenKey)
    private var hiddenCSV: String = ""

    // Per-tier order — backed by individual @AppStorage entries
    // because @AppStorage values must be statically known at
    // declaration time (no key-by-tier indirection at the wrapper).
    @AppStorage("dashboard.cardOrder.1") private var orderCoreCSV:    String = ""
    @AppStorage("dashboard.cardOrder.2") private var orderFitnessCSV: String = ""
    @AppStorage("dashboard.cardOrder.3") private var orderWellnessCSV: String = ""

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
            .toolbar { editToolbarItem }
            .refreshable {
                // Pull-to-refresh — full reload bypassing the 5-min
                // TTL. Distinct from save-path invalidation: this
                // refetches every catalog metric, useful when the
                // user knows new data exists in Apple Health (e.g.
                // they just finished a workout on the Watch and
                // want to confirm it landed).
                await service.refresh()
            }
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

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var editToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            // Hide the button entirely if there are no cards yet —
            // editing an empty dashboard would just be confusing.
            if anyVisibleCardsAcrossTiers {
                Button(editing ? "Done" : "Edit") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editing.toggle()
                    }
                }
                .accessibilityLabel(editing ? "Done editing dashboard" : "Edit dashboard")
            }
        }
    }

    private var anyVisibleCardsAcrossTiers: Bool {
        !coreVitalsCards.isEmpty || !fitnessCards.isEmpty || !wellnessCards.isEmpty
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
                    cardRow(summary, in: .coreVitals)
                }
            }
        }
    }

    // MARK: Tier 2 — Fitness

    private var fitnessSection: some View {
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
                        cardRow(summary, in: .fitness)
                    }
                }
            }
        }
    }

    // MARK: Tier 3 — Wellness

    private var wellnessSection: some View {
        TierSection(
            tier: .wellness,
            icon: "leaf.fill",
            hasContent: tier3HasAnyCardsOrAuth
        ) {
            VStack(spacing: 12) {
                if wellnessCards.isEmpty {
                    EmptyTierMessage(
                        text: "No Wellness data yet. Log a meditation, drink some water, or fill in your food diary — these cards populate from Apple Health automatically."
                    )
                } else {
                    ForEach(wellnessCards) { summary in
                        cardRow(summary, in: .wellness)
                    }
                }
            }
        }
    }

    // MARK: Card row (with optional edit-mode chrome)

    @ViewBuilder
    private func cardRow(_ summary: MetricSummary, in tier: HealthMetric.Tier) -> some View {
        if editing {
            HStack(alignment: .center, spacing: 8) {
                MetricCard(summary: summary)
                    // Tapping the card while editing shouldn't open
                    // the detail sheet — let the buttons do their
                    // jobs. `allowsHitTesting(false)` on a Button is
                    // the simplest way to neutralise it.
                    .allowsHitTesting(false)

                VStack(spacing: 6) {
                    moveButton(summary, in: tier, direction: .up)
                    moveButton(summary, in: tier, direction: .down)
                    hideButton(summary)
                }
                .padding(.trailing, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.emerald.opacity(0.4), lineWidth: 1)
            )
        } else {
            MetricCard(summary: summary)
        }
    }

    private enum MoveDir { case up, down }

    private func moveButton(_ summary: MetricSummary, in tier: HealthMetric.Tier, direction: MoveDir) -> some View {
        let canMove = canMove(summary, in: tier, direction: direction)
        return Button {
            move(summary, in: tier, direction: direction)
        } label: {
            Image(systemName: direction == .up ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(canMove ? Color.emerald : Color.secondary.opacity(0.4))
                .frame(width: 28, height: 22)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(!canMove)
        .accessibilityLabel(direction == .up ? "Move \(summary.metric.label) up" : "Move \(summary.metric.label) down")
    }

    private func hideButton(_ summary: MetricSummary) -> some View {
        Button {
            hide(summary)
        } label: {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.fieldNotesAlert)
                .frame(width: 28, height: 22)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityLabel("Hide \(summary.metric.label)")
    }

    // MARK: Reorder + hide actions

    private func canMove(_ summary: MetricSummary, in tier: HealthMetric.Tier, direction: MoveDir) -> Bool {
        let cards = visibleCards(in: tier)
        guard let i = cards.firstIndex(where: { $0.metric.id == summary.metric.id }) else { return false }
        return direction == .up ? i > 0 : i < cards.count - 1
    }

    private func move(_ summary: MetricSummary, in tier: HealthMetric.Tier, direction: MoveDir) {
        var ids = visibleCards(in: tier).map { $0.metric.id }
        guard let i = ids.firstIndex(of: summary.metric.id) else { return }
        let j = direction == .up ? i - 1 : i + 1
        guard ids.indices.contains(j) else { return }
        ids.swapAt(i, j)
        write(orderCSV: DashboardCustomization.encode(ids), for: tier)
    }

    private func hide(_ summary: MetricSummary) {
        var hidden = Set(DashboardCustomization.decode(hiddenCSV))
        hidden.insert(summary.metric.id)
        hiddenCSV = DashboardCustomization.encode(Array(hidden).sorted())
    }

    private func write(orderCSV csv: String, for tier: HealthMetric.Tier) {
        switch tier {
        case .coreVitals: orderCoreCSV    = csv
        case .fitness:    orderFitnessCSV = csv
        case .wellness:   orderWellnessCSV = csv
        }
    }

    private func orderCSV(for tier: HealthMetric.Tier) -> String {
        switch tier {
        case .coreVitals: return orderCoreCSV
        case .fitness:    return orderFitnessCSV
        case .wellness:   return orderWellnessCSV
        }
    }

    // MARK: Filtering — applies hide + order on top of the
    // base hasData filter from Phase A.

    private var hidden: Set<String> {
        Set(DashboardCustomization.decode(hiddenCSV))
    }

    private func visibleCards(in tier: HealthMetric.Tier) -> [MetricSummary] {
        let base = HealthMetric.all
            .filter { $0.tier == tier }
            .compactMap { service.summaries[$0.id] }
            .filter { $0.hasData && !hidden.contains($0.metric.id) }
        return DashboardCustomization.ordered(
            base,
            order: DashboardCustomization.decode(orderCSV(for: tier))
        )
    }

    private var coreVitalsCards: [MetricSummary] { visibleCards(in: .coreVitals) }
    private var fitnessCards:    [MetricSummary] { visibleCards(in: .fitness) }
    private var wellnessCards:   [MetricSummary] { visibleCards(in: .wellness) }

    // MARK: Tier-content gates (unchanged from Phase B/C)

    private var tier2HasAnyCardsOrAuth: Bool {
        service.hasRequestedAuth || !fitnessCards.isEmpty
    }

    private var tier3HasAnyCardsOrAuth: Bool {
        service.hasRequestedAuth || !wellnessCards.isEmpty
    }

    private var shouldShowAuthHandshake: Bool {
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

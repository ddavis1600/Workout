import SwiftUI
import HealthKit

// MARK: - Period

enum HeartRatePeriod: String, CaseIterable {
    case weekly  = "Weekly"
    case monthly = "Monthly"
    case yearly  = "Yearly"

    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let cal = Calendar.current
        switch self {
        case .weekly:  return (cal.date(byAdding: .weekOfYear, value: -1, to: now)!, now)
        case .monthly: return (cal.date(byAdding: .month,      value: -1, to: now)!, now)
        case .yearly:  return (cal.date(byAdding: .year,       value: -1, to: now)!, now)
        }
    }
}

// MARK: - View

struct HeartRateView: View {
    @State private var viewModel = HeartRateViewModel()
    @State private var showZoneSettings = false
    /// Focus state for the Age field so we can dismiss its numberPad
    /// keyboard from a "Done" toolbar button — numberPad has no Return key.
    @FocusState private var ageFieldFocused: Bool

    private func zoneColor(_ colorName: String) -> Color {
        switch colorName {
        case "gray":   return .gray
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        default:       return .gray
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Period picker
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(HeartRatePeriod.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.slateBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                currentHeartRateSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                zoneIndicatorSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                restingHRSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                historicalZonesSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                settingsSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showZoneSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.slateText)
                    }
                }
                // The Age field uses .numberPad — there's no Return / Done key
                // on that keyboard, so without this toolbar the user has no
                // way to dismiss it after editing.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        ageFieldFocused = false
                    }
                    .foregroundStyle(Color.emerald)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showZoneSettings) {
                ZoneSettingsSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.setup()
            }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                Task { await viewModel.fetchStats() }
            }
            .onDisappear {
                viewModel.stopMonitoring()
            }
        }
    }

    // MARK: - Current Heart Rate

    private var currentHeartRateSection: some View {
        VStack(spacing: 16) {
            if viewModel.isAuthorized {
                let zone = viewModel.currentZone
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(zoneColor(zone.color))
                        .symbolEffect(.pulse, options: .repeating, value: viewModel.service.currentBPM > 0)

                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.service.currentBPM > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(viewModel.service.currentBPM)")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.ink)
                                Text("BPM")
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.slateText)
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(.slateText)
                            Text("Waiting for data...")
                                .font(.subheadline)
                                .foregroundColor(.slateText)
                        }
                    }

                    Spacer()
                }

                if viewModel.service.currentBPM > 0 {
                    Text("Last updated: \(viewModel.lastUpdatedString)")
                        .font(.caption)
                        .foregroundColor(.slateText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.slateText)

                    Text("Heart Rate Access Required")
                        .font(.headline)
                        .foregroundColor(Color.ink)

                    Text("Grant HealthKit access to see your Apple Watch heart rate data.")
                        .font(.subheadline)
                        .foregroundColor(.slateText)
                        .multilineTextAlignment(.center)

                    Button("Enable Access") {
                        Task { await viewModel.requestAccess() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.emerald)
                }
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    // MARK: - Zone Indicator

    private var zoneIndicatorSection: some View {
        VStack(spacing: 12) {
            if viewModel.service.currentBPM > 0 {
                let zone = viewModel.currentZone

                HStack {
                    Text("Current Zone")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.slateText)
                    Spacer()
                    Text(zone.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(zoneColor(zone.color))
                }

                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let zones = HeartRateZone.allZones(maxHR: viewModel.maxHeartRate)

                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            ForEach(zones) { z in
                                let fraction = Double(z.maxBPM - z.minBPM) / Double(viewModel.maxHeartRate)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(zoneColor(z.color).opacity(z.number == zone.number ? 1.0 : 0.3))
                                    .frame(width: max(0, totalWidth * fraction - 2))
                            }
                        }
                        .frame(height: 12)

                        let position = Double(viewModel.service.currentBPM) / Double(viewModel.maxHeartRate)
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: min(totalWidth - 16, max(0, totalWidth * position - 8)))
                    }
                }
                .frame(height: 16)

                Text(zone.description)
                    .font(.caption)
                    .foregroundColor(.slateText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    // MARK: - Resting HR

    private var restingHRSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resting Heart Rate")
                .font(.headline)
                .foregroundColor(Color.ink)

            if let s = viewModel.restingStats {
                HStack(spacing: 0) {
                    statPill(label: "Avg", value: s.avg, color: .emerald)
                    statPill(label: "Min", value: s.min, color: .blue)
                    statPill(label: "Max", value: s.max, color: .red)
                }
            } else {
                Text("No resting HR data for this period")
                    .font(.subheadline)
                    .foregroundColor(.slateText)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private func statPill(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Historical Zone Breakdown

    private var historicalZonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zone Breakdown (\(viewModel.selectedPeriod.rawValue))")
                .font(.headline)
                .foregroundColor(Color.ink)

            if viewModel.historicalZoneFractions.isEmpty {
                Text("No heart rate data for this period")
                    .font(.subheadline)
                    .foregroundColor(.slateText)
            } else {
                let zoneColors: [Int: Color] = [1: .gray, 2: .blue, 3: .green, 4: .orange, 5: .red]
                let zoneNames:  [Int: String] = [1: "Warm Up", 2: "Fat Burn", 3: "Cardio", 4: "Hard", 5: "Max"]
                let boundaries = viewModel.zoneBoundaries

                ForEach(1...5, id: \.self) { zone in
                    let fraction = viewModel.historicalZoneFractions[zone] ?? 0
                    let color = zoneColors[zone] ?? .gray
                    let name  = zoneNames[zone]  ?? "Zone \(zone)"
                    let bpmLabel = zoneBPMLabel(zone: zone, boundaries: boundaries)
                    let minutes = viewModel.historicalZoneMinutes[zone] ?? 0

                    VStack(spacing: 4) {
                        HStack {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            Text("Z\(zone): \(name)")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Color.ink)
                            Spacer()
                            Text(bpmLabel)
                                .font(.caption2)
                                .foregroundColor(.slateText)
                            Text("\(minutes) min · \(Int(fraction * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(color)
                                .frame(minWidth: 80, alignment: .trailing)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.slateBorder)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color)
                                    .frame(width: max(0, geo.size.width * fraction), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private func zoneBPMLabel(zone: Int, boundaries: [Int]) -> String {
        switch zone {
        case 1: return "<\(boundaries[0])"
        case 2: return "\(boundaries[0])–\(boundaries[1])"
        case 3: return "\(boundaries[1])–\(boundaries[2])"
        case 4: return "\(boundaries[2])–\(boundaries[3])"
        case 5: return ">\(boundaries[3])"
        default: return ""
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Age")
                    .foregroundColor(Color.ink)
                Spacer()
                TextField("Age", value: $viewModel.userAge, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.emerald)
                    .frame(width: 60)
                    .focused($ageFieldFocused)
            }

            HStack {
                Text("Max Heart Rate")
                    .foregroundColor(Color.ink)
                Spacer()
                Text("\(viewModel.maxHeartRate) BPM")
                    .foregroundColor(.slateText)
            }

            Text("Max HR = 220 - age. Zones are calculated from this value.")
                .font(.caption)
                .foregroundColor(.slateText)
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }
}

// MARK: - Zone Settings Sheet

struct ZoneSettingsSheet: View {
    // `viewModel` is an @Observable reference type — no need for @Bindable
    // since this sheet doesn't expose a `$viewModel.boundaries` binding to
    // any SwiftUI control. It mutates the property directly on Save.
    let viewModel: HeartRateViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var boundaries: [Int] = [115, 135, 155, 175]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Set the upper BPM boundary for each zone. Zone 5 covers everything above Zone 4's limit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        Text("Zone \(i + 1) max")
                        Spacer()
                        TextField("BPM", value: $boundaries[i], format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section {
                    HStack {
                        Text("Zone 5")
                        Spacer()
                        Text(">\(boundaries[3]) BPM")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Zone Boundaries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.zoneBoundaries = boundaries
                        Task { await viewModel.fetchStats() }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            boundaries = viewModel.zoneBoundaries
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class HeartRateViewModel {
    let service = HeartRateService()
    var isAuthorized = false
    var selectedPeriod: HeartRatePeriod = .weekly
    var restingStats: (avg: Int, min: Int, max: Int)? = nil
    var historicalZoneFractions: [Int: Double] = [:]
    var historicalZoneMinutes: [Int: Int] = [:]

    /// Persisted to UserDefaults via didSet. Read once at init so SwiftUI's
    /// @Observable tracker sees a real stored property — view bodies that
    /// reference `vm.userAge` will re-render on assignment.
    var userAge: Int {
        didSet {
            UserDefaults.standard.set(userAge, forKey: "heartRateUserAge")
        }
    }

    var maxHeartRate: Int { 220 - userAge }

    /// Zone boundaries: [z1max, z2max, z3max, z4max].
    /// Defaults: Z1 <115, Z2 115–135, Z3 135–155, Z4 155–175, Z5 >175.
    /// Was a UserDefaults-computed property under ObservableObject — that
    /// pattern doesn't work under @Observable because the macro only tracks
    /// stored-property accesses, so views wouldn't re-render on change.
    /// Now a stored var read once in init() with didSet writing back to
    /// UserDefaults — change-tracking is automatic.
    var zoneBoundaries: [Int] {
        didSet {
            UserDefaults.standard.set(zoneBoundaries, forKey: "hrZoneBoundaries")
        }
    }

    init() {
        let savedAge = UserDefaults.standard.integer(forKey: "heartRateUserAge")
        self.userAge = savedAge == 0 ? 25 : savedAge
        self.zoneBoundaries =
            (UserDefaults.standard.array(forKey: "hrZoneBoundaries") as? [Int])
            ?? [115, 135, 155, 175]
    }

    var currentZone: HeartRateZone {
        HeartRateZone.zone(for: service.currentBPM, maxHR: maxHeartRate)
    }

    var lastUpdatedString: String {
        guard let date = service.lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func setup() async {
        // userAge / zoneBoundaries are loaded from UserDefaults in init() now,
        // so we no longer reload them here.
        guard HealthKitManager.shared.isAvailable else { return }

        // Give UIKit a beat to attach this view's presentation host to the
        // window before kicking off the HK auth request. `.task` fires the
        // instant the view enters SwiftUI's tree, which can be slightly
        // ahead of when the presenter is ready — especially when the user
        // taps the Heart tab right after the launch splash dismisses, or
        // when opening the tab from a minimized-workout state.
        //
        // Without this delay the system logs:
        //   "Attempt to present … whose view is not in the window hierarchy"
        // and the HK permission sheet silently times out — the user never
        // sees the prompt and the app has no HR access for the session.
        try? await Task.sleep(for: .milliseconds(500))

        let authorized = await HealthKitManager.shared.requestAuthorization()
        isAuthorized = authorized
        if authorized {
            await service.startMonitoring()
            await fetchStats()
        }
    }

    /// User-initiated auth (from the "Grant Access" button). No delay needed
    /// — a tap is always on a view that's fully in the hierarchy.
    func requestAccess() async {
        let authorized = await HealthKitManager.shared.requestAuthorization()
        isAuthorized = authorized
        if authorized {
            await service.startMonitoring()
            await fetchStats()
        }
    }

    func stopMonitoring() {
        service.stopMonitoring()
    }

    func fetchStats() async {
        let range = selectedPeriod.dateRange
        async let resting = HealthKitManager.shared.fetchRestingHeartRateStats(from: range.start, to: range.end)
        async let samples = HealthKitManager.shared.fetchHeartRateSamples(from: range.start, to: range.end)
        let (restingResult, samplesResult) = await (resting, samples)
        restingStats = restingResult
        historicalZoneFractions = computeZoneFractions(samples: samplesResult)
        historicalZoneMinutes = computeZoneMinutes(samples: samplesResult)
    }

    private func computeZoneMinutes(samples: [(Date, Int)]) -> [Int: Int] {
        guard samples.count > 1 else { return [:] }
        let sorted = samples.sorted { $0.0 < $1.0 }
        let boundaries = zoneBoundaries
        var seconds: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for i in 0..<sorted.count - 1 {
            let (t1, bpm) = sorted[i]
            let t2 = sorted[i + 1].0
            let interval = min(t2.timeIntervalSince(t1), 300)
            let zone: Int
            if bpm < boundaries[0]      { zone = 1 }
            else if bpm < boundaries[1] { zone = 2 }
            else if bpm < boundaries[2] { zone = 3 }
            else if bpm < boundaries[3] { zone = 4 }
            else                        { zone = 5 }
            seconds[zone, default: 0] += interval
        }
        return seconds.mapValues { Int($0 / 60) }
    }

    private func computeZoneFractions(samples: [(Date, Int)]) -> [Int: Double] {
        guard !samples.isEmpty else { return [:] }
        let boundaries = zoneBoundaries
        var counts: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for (_, bpm) in samples {
            let zone: Int
            if bpm < boundaries[0]      { zone = 1 }
            else if bpm < boundaries[1] { zone = 2 }
            else if bpm < boundaries[2] { zone = 3 }
            else if bpm < boundaries[3] { zone = 4 }
            else                        { zone = 5 }
            counts[zone, default: 0] += 1
        }
        let total = Double(samples.count)
        return counts.mapValues { Double($0) / total }
    }
}

#Preview {
    HeartRateView()
}

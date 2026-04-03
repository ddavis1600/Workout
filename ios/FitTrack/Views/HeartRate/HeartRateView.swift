import SwiftUI
import HealthKit

struct HeartRateView: View {
    @StateObject private var viewModel = HeartRateViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Current BPM display
                currentHeartRateSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Zone indicator
                zoneIndicatorSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                // Zone breakdown
                zonesSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                // Settings
                settingsSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Heart Rate")
            .task {
                await viewModel.setup()
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
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.currentZone.color)
                        .symbolEffect(.pulse, options: .repeating, value: viewModel.currentBPM > 0)

                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.currentBPM > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(viewModel.currentBPM)")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
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

                if viewModel.currentBPM > 0 {
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
                        .foregroundColor(.white)

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
            if viewModel.currentBPM > 0 {
                let zone = viewModel.currentZone

                HStack {
                    Text("Current Zone")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.slateText)
                    Spacer()
                    Text(zone.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(zone.color)
                }

                // Zone bar
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let zones = HeartRateZone.allZones(maxHR: viewModel.maxHeartRate)

                    ZStack(alignment: .leading) {
                        // Zone segments
                        HStack(spacing: 2) {
                            ForEach(zones) { z in
                                let fraction = Double(z.maxBPM - z.minBPM) / Double(viewModel.maxHeartRate)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(z.color.opacity(z.number == zone.number ? 1.0 : 0.3))
                                    .frame(width: max(0, totalWidth * fraction - 2))
                            }
                        }
                        .frame(height: 12)

                        // Current position indicator
                        let position = Double(viewModel.currentBPM) / Double(viewModel.maxHeartRate)
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

    // MARK: - Zones Breakdown

    private var zonesSection: some View {
        VStack(spacing: 12) {
            Text("Heart Rate Zones")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(HeartRateZone.allZones(maxHR: viewModel.maxHeartRate)) { zone in
                HStack(spacing: 12) {
                    Circle()
                        .fill(zone.color)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zone \(zone.number): \(zone.name)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(viewModel.currentZone.number == zone.number ? zone.color : .white)
                        Text(zone.description)
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }

                    Spacer()

                    Text("\(zone.minBPM)–\(zone.maxBPM)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(viewModel.currentZone.number == zone.number ? zone.color : .slateText)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Age")
                    .foregroundColor(.white)
                Spacer()
                TextField("Age", value: $viewModel.userAge, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.emerald)
                    .frame(width: 60)
            }

            HStack {
                Text("Max Heart Rate")
                    .foregroundColor(.white)
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

// MARK: - Heart Rate Zone Model

struct HeartRateZone: Identifiable {
    let number: Int
    let name: String
    let description: String
    let minPercent: Double
    let maxPercent: Double
    let color: Color
    let minBPM: Int
    let maxBPM: Int

    var id: Int { number }

    static func allZones(maxHR: Int) -> [HeartRateZone] {
        [
            HeartRateZone(number: 1, name: "Warm Up", description: "Easy effort, recovery pace",
                         minPercent: 0.50, maxPercent: 0.60, color: .gray,
                         minBPM: Int(Double(maxHR) * 0.50), maxBPM: Int(Double(maxHR) * 0.60)),
            HeartRateZone(number: 2, name: "Fat Burn", description: "Light effort, conversational pace",
                         minPercent: 0.60, maxPercent: 0.70, color: .blue,
                         minBPM: Int(Double(maxHR) * 0.60), maxBPM: Int(Double(maxHR) * 0.70)),
            HeartRateZone(number: 3, name: "Cardio", description: "Moderate effort, steady state",
                         minPercent: 0.70, maxPercent: 0.80, color: .green,
                         minBPM: Int(Double(maxHR) * 0.70), maxBPM: Int(Double(maxHR) * 0.80)),
            HeartRateZone(number: 4, name: "Hard", description: "Hard effort, threshold training",
                         minPercent: 0.80, maxPercent: 0.90, color: .orange,
                         minBPM: Int(Double(maxHR) * 0.80), maxBPM: Int(Double(maxHR) * 0.90)),
            HeartRateZone(number: 5, name: "Max", description: "All-out effort, peak performance",
                         minPercent: 0.90, maxPercent: 1.00, color: .red,
                         minBPM: Int(Double(maxHR) * 0.90), maxBPM: maxHR),
        ]
    }

    static func zone(for bpm: Int, maxHR: Int) -> HeartRateZone {
        let zones = allZones(maxHR: maxHR)
        let percent = Double(bpm) / Double(maxHR)
        if percent >= 0.90 { return zones[4] }
        if percent >= 0.80 { return zones[3] }
        if percent >= 0.70 { return zones[2] }
        if percent >= 0.60 { return zones[1] }
        return zones[0]
    }
}

// MARK: - View Model

@MainActor
class HeartRateViewModel: ObservableObject {
    @Published var currentBPM: Int = 0
    @Published var isAuthorized = false
    @Published var lastUpdated: Date?
    @Published var userAge: Int = 25 {
        didSet {
            UserDefaults.standard.set(userAge, forKey: "heartRateUserAge")
        }
    }

    private let manager = HealthKitManager.shared
    private var heartRateQuery: HKAnchoredObjectQuery?

    var maxHeartRate: Int { 220 - userAge }

    var currentZone: HeartRateZone {
        HeartRateZone.zone(for: currentBPM, maxHR: maxHeartRate)
    }

    var lastUpdatedString: String {
        guard let date = lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func setup() async {
        userAge = UserDefaults.standard.integer(forKey: "heartRateUserAge")
        if userAge == 0 { userAge = 25 }

        guard manager.isAvailable else { return }
        let authorized = await manager.requestAuthorization()
        isAuthorized = authorized
        if authorized {
            startMonitoring()
        }
    }

    func requestAccess() async {
        let authorized = await manager.requestAuthorization()
        isAuthorized = authorized
        if authorized {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard manager.isAvailable else { return }
        let heartRateType = HKQuantityType(.heartRate)

        // First fetch the most recent heart rate sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let recentQuery = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            Task { @MainActor in
                self?.currentBPM = bpm
                self?.lastUpdated = sample.startDate
            }
        }
        manager.healthStore.execute(recentQuery)

        // Then set up live monitoring with anchored query
        let anchorQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleHeartRateSamples(samples)
        }

        anchorQuery.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHeartRateSamples(samples)
        }

        heartRateQuery = anchorQuery
        manager.healthStore.execute(anchorQuery)
    }

    func stopMonitoring() {
        if let query = heartRateQuery {
            manager.healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    nonisolated private func handleHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample],
              let mostRecent = heartRateSamples.last else { return }

        let bpm = Int(mostRecent.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        let date = mostRecent.startDate
        Task { @MainActor [weak self] in
            self?.currentBPM = bpm
            self?.lastUpdated = date
        }
    }
}

#Preview {
    HeartRateView()
}

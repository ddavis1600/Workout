import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @Query private var allSets: [WorkoutSet]

    private var displayName: String {
        workout.name.isEmpty ? "Workout" : workout.name
    }

    /// Map a stored `workoutType` tag to a human-friendly label.
    /// Mirrors the catalog in `LogWorkoutView.workoutTypeOptions` —
    /// kept inline so the detail view doesn't need to depend on the
    /// log view's struct namespace.
    private func workoutTypeLabel(_ id: String) -> String {
        switch id {
        case "strength":  return "Strength"
        case "running":   return "Running"
        case "cycling":   return "Cycling"
        case "walking":   return "Walking"
        case "hiit":      return "HIIT"
        case "yoga":      return "Yoga"
        case "swimming":  return "Swimming"
        case "other":     return "Other"
        default:          return id.capitalized
        }
    }

    private func workoutTypeIcon(_ id: String) -> String {
        switch id {
        case "running":   return "figure.run"
        case "cycling":   return "bicycle"
        case "walking":   return "figure.walk"
        case "hiit":      return "flame.fill"
        case "yoga":      return "figure.mind.and.body"
        case "swimming":  return "figure.pool.swim"
        case "other":     return "figure.flexibility"
        default:          return "dumbbell.fill"
        }
    }

    private var exerciseGroups: [(exercise: String, sets: [WorkoutSet])] {
        var groups: [String: [WorkoutSet]] = [:]
        var order: [String] = []

        for set in (workout.sets ?? []).sorted(by: { $0.setNumber < $1.setNumber }) {
            let name = set.exercise?.name ?? "Unknown"
            if groups[name] == nil {
                order.append(name)
                groups[name] = []
            }
            groups[name]?.append(set)
        }

        return order.map { (exercise: $0, sets: groups[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let photoData = workout.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    headerSection
                    if workout.avgHeartRate != nil {
                        heartRateSection
                    }
                    exerciseSections
                }
                .padding()
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                StatCard(
                    icon: "calendar",
                    title: "Date",
                    value: workout.date.formatted(as: "MMM d, yyyy")
                )
            }

            if let duration = workout.durationMinutes, duration > 0 {
                StatCard(
                    icon: "clock",
                    title: "Duration",
                    value: "\(duration) min"
                )
            }

            // Surface the workout type (strength / running / cycling /
            // etc.) when set so the detail view reflects what the user
            // picked at log time. Legacy workouts saved before the
            // picker existed render no type row at all rather than
            // a misleading "Strength" default.
            if let typeID = workout.workoutType, !typeID.isEmpty {
                StatCard(
                    icon: workoutTypeIcon(typeID),
                    title: "Type",
                    value: workoutTypeLabel(typeID)
                )
            }

            if !workout.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                    Text(workout.notes)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.slateBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Heart Rate Summary

    private func zoneColor(_ colorName: String) -> Color {
        switch colorName {
        case "gray": return .gray
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Heart Rate")
                    .font(.headline)
                    .foregroundColor(Color.ink)
            }

            // Stats row
            HStack(spacing: 0) {
                if let avg = workout.avgHeartRate {
                    VStack(spacing: 2) {
                        Text("\(avg)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.ink)
                        Text("Avg BPM")
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }
                    .frame(maxWidth: .infinity)
                }
                if let max = workout.maxHeartRate {
                    Divider().frame(height: 30).overlay(Color.slateBorder)
                    VStack(spacing: 2) {
                        Text("\(max)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("Max BPM")
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }
                    .frame(maxWidth: .infinity)
                }
                if let min = workout.minHeartRate {
                    Divider().frame(height: 30).overlay(Color.slateBorder)
                    VStack(spacing: 2) {
                        Text("\(min)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("Min BPM")
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Zone duration bars
            let zoneDurations: [(zone: Int, seconds: Double)] = [
                (1, workout.hrZone1Seconds ?? 0),
                (2, workout.hrZone2Seconds ?? 0),
                (3, workout.hrZone3Seconds ?? 0),
                (4, workout.hrZone4Seconds ?? 0),
                (5, workout.hrZone5Seconds ?? 0),
            ]
            let totalTime = zoneDurations.map(\.seconds).reduce(0, +)
            let userAge = UserDefaults.standard.integer(forKey: "heartRateUserAge")
            let maxHR = 220 - (userAge > 0 ? userAge : 25)
            let zones = HeartRateZone.allZones(maxHR: maxHR)

            if totalTime > 0 {
                VStack(spacing: 6) {
                    Text("Time in Zones")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.slateText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(zones) { zone in
                        let duration = zoneDurations.first(where: { $0.zone == zone.number })?.seconds ?? 0
                        let fraction = duration / totalTime

                        HStack(spacing: 8) {
                            Text("Z\(zone.number)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(zoneColor(zone.color))
                                .frame(width: 22, alignment: .leading)

                            Text(zone.name)
                                .font(.system(size: 11))
                                .foregroundColor(.slateText)
                                .frame(width: 56, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.slateBorder)
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(zoneColor(zone.color))
                                        .frame(width: geo.size.width * fraction, height: 8)
                                }
                            }
                            .frame(height: 8)

                            Text(formatDuration(duration))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.slateText)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }

    // MARK: - Exercise Sections

    private var exerciseSections: some View {
        ForEach(exerciseGroups, id: \.exercise) { group in
            VStack(alignment: .leading, spacing: 10) {
                Text(group.exercise)
                    .font(.headline)
                    .foregroundStyle(Color.emerald)

                // Table header
                HStack {
                    Text("Set")
                        .frame(width: 36, alignment: .leading)
                    Text("Reps")
                        .frame(width: 50, alignment: .center)
                    Text("Weight")
                        .frame(width: 70, alignment: .center)
                    Text("RPE")
                        .frame(width: 40, alignment: .center)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.slateText)
                .padding(.horizontal, 4)

                Divider()
                    .overlay(Color.slateBorder)

                ForEach(group.sets, id: \.self) { workoutSet in
                    let prTypes = PRService.checkForPRs(
                        exerciseName: group.exercise,
                        reps: workoutSet.reps,
                        weight: workoutSet.weight,
                        allSets: allSets.filter { $0.workout?.date ?? Date() < workout.date }
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("#\(workoutSet.setNumber)")
                                .frame(width: 36, alignment: .leading)
                            Text(workoutSet.reps != nil ? "\(workoutSet.reps!)" : "-")
                                .frame(width: 50, alignment: .center)
                            Text(workoutSet.weight != nil ? "\(workoutSet.weight!, specifier: "%.1f")" : "-")
                                .frame(width: 70, alignment: .center)
                            Text(workoutSet.rpe != nil ? "\(workoutSet.rpe!, specifier: "%.1f")" : "-")
                                .frame(width: 40, alignment: .center)
                            if !prTypes.isEmpty {
                                PRBadgeView(prTypes: prTypes)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)

                        if !workoutSet.notes.isEmpty {
                            Text(workoutSet.notes)
                                .font(.caption)
                                .foregroundStyle(Color.slateText)
                                .padding(.leading, 36)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )
        }
    }
}

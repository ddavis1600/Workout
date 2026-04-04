import Foundation
import SwiftData

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
}

enum DataExportService {
    // MARK: - JSON Export

    static func exportJSON(context: ModelContext) -> URL? {
        var data: [String: Any] = [:]
        data["exportDate"] = ISO8601DateFormatter().string(from: Date())
        data["workouts"] = exportWorkouts(context: context)
        data["measurements"] = exportMeasurements(context: context)
        data["habits"] = exportHabits(context: context)
        data["weightEntries"] = exportWeightEntries(context: context)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fittrack_backup.json")
        try? jsonData.write(to: url)
        return url
    }

    // MARK: - CSV Export

    static func exportCSV(context: ModelContext) -> [URL] {
        var urls: [URL] = []

        if let url = exportWorkoutsCSV(context: context) { urls.append(url) }
        if let url = exportMeasurementsCSV(context: context) { urls.append(url) }
        if let url = exportWeightCSV(context: context) { urls.append(url) }

        return urls
    }

    // MARK: - Workout Data

    private static func exportWorkouts(context: ModelContext) -> [[String: Any]] {
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let workouts = try? context.fetch(descriptor) else { return [] }

        return workouts.map { w in
            var dict: [String: Any] = [
                "name": w.name,
                "date": ISO8601DateFormatter().string(from: w.date),
                "notes": w.notes,
                "durationMinutes": w.durationMinutes as Any
            ]
            dict["sets"] = w.sets.sorted(by: { $0.setNumber < $1.setNumber }).map { s in
                [
                    "exercise": s.exercise?.name ?? "",
                    "setNumber": s.setNumber,
                    "reps": s.reps as Any,
                    "weight": s.weight as Any,
                    "rpe": s.rpe as Any,
                    "notes": s.notes
                ] as [String: Any]
            }
            return dict
        }
    }

    private static func exportWorkoutsCSV(context: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let workouts = try? context.fetch(descriptor) else { return nil }

        var csv = "Date,Workout Name,Exercise,Set,Reps,Weight,RPE,Notes\n"
        for w in workouts {
            for s in w.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                let row = [
                    w.date.formatted(as: "yyyy-MM-dd"),
                    escapeCSV(w.name),
                    escapeCSV(s.exercise?.name ?? ""),
                    "\(s.setNumber)",
                    s.reps.map(String.init) ?? "",
                    s.weight.map { String(format: "%.1f", $0) } ?? "",
                    s.rpe.map { String(format: "%.1f", $0) } ?? "",
                    escapeCSV(s.notes)
                ].joined(separator: ",")
                csv += row + "\n"
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("workouts.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Measurements Data

    private static func exportMeasurements(context: ModelContext) -> [[String: Any]] {
        let descriptor = FetchDescriptor<BodyMeasurement>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let measurements = try? context.fetch(descriptor) else { return [] }

        return measurements.map { m in
            [
                "date": ISO8601DateFormatter().string(from: m.date),
                "chest": m.chest as Any,
                "waist": m.waist as Any,
                "hips": m.hips as Any,
                "shoulders": m.shoulders as Any,
                "neck": m.neck as Any,
                "bicepLeft": m.bicepLeft as Any,
                "bicepRight": m.bicepRight as Any,
                "thighLeft": m.thighLeft as Any,
                "thighRight": m.thighRight as Any,
                "bodyFatPercent": m.bodyFatPercent as Any
            ] as [String: Any]
        }
    }

    private static func exportMeasurementsCSV(context: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<BodyMeasurement>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let measurements = try? context.fetch(descriptor), !measurements.isEmpty else { return nil }

        var csv = "Date,Chest,Waist,Hips,Shoulders,Neck,Bicep L,Bicep R,Thigh L,Thigh R,Body Fat %\n"
        for m in measurements {
            let row = [
                m.date.formatted(as: "yyyy-MM-dd"),
                m.chest.map { String(format: "%.1f", $0) } ?? "",
                m.waist.map { String(format: "%.1f", $0) } ?? "",
                m.hips.map { String(format: "%.1f", $0) } ?? "",
                m.shoulders.map { String(format: "%.1f", $0) } ?? "",
                m.neck.map { String(format: "%.1f", $0) } ?? "",
                m.bicepLeft.map { String(format: "%.1f", $0) } ?? "",
                m.bicepRight.map { String(format: "%.1f", $0) } ?? "",
                m.thighLeft.map { String(format: "%.1f", $0) } ?? "",
                m.thighRight.map { String(format: "%.1f", $0) } ?? "",
                m.bodyFatPercent.map { String(format: "%.1f", $0) } ?? ""
            ].joined(separator: ",")
            csv += row + "\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("measurements.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Habits

    private static func exportHabits(context: ModelContext) -> [[String: Any]] {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.name)])
        guard let habits = try? context.fetch(descriptor) else { return [] }

        return habits.map { h in
            [
                "name": h.name,
                "icon": h.icon,
                "completions": h.completions.map { c in
                    ["date": ISO8601DateFormatter().string(from: c.date)]
                }
            ] as [String: Any]
        }
    }

    // MARK: - Weight

    private static func exportWeightEntries(context: ModelContext) -> [[String: Any]] {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let entries = try? context.fetch(descriptor) else { return [] }

        return entries.map { e in
            [
                "date": ISO8601DateFormatter().string(from: e.date),
                "weight": e.weight
            ] as [String: Any]
        }
    }

    private static func exportWeightCSV(context: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else { return nil }

        var csv = "Date,Weight\n"
        for e in entries {
            csv += "\(e.date.formatted(as: "yyyy-MM-dd")),\(String(format: "%.1f", e.weight))\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("weight.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Helpers

    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}

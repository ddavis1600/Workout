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
            var dict: [String: Any] = [:]
            dict["name"] = w.name
            dict["date"] = ISO8601DateFormatter().string(from: w.date)
            dict["notes"] = w.notes
            dict["durationMinutes"] = w.durationMinutes as Any

            let setsArray: [[String: Any]] = (w.sets ?? []).sorted(by: { $0.setNumber < $1.setNumber }).map { s in
                var setDict: [String: Any] = [:]
                setDict["exercise"] = s.exercise?.name ?? ""
                setDict["setNumber"] = s.setNumber
                setDict["reps"] = s.reps as Any
                setDict["weight"] = s.weight as Any
                setDict["rpe"] = s.rpe as Any
                setDict["notes"] = s.notes
                return setDict
            }
            dict["sets"] = setsArray
            return dict
        }
    }

    private static func exportWorkoutsCSV(context: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let workouts = try? context.fetch(descriptor) else { return nil }

        var csv = "Date,Workout Name,Exercise,Set,Reps,Weight,RPE,Notes\n"
        for w in workouts {
            for s in (w.sets ?? []).sorted(by: { $0.setNumber < $1.setNumber }) {
                let dateStr = w.date.formatted(as: "yyyy-MM-dd")
                let nameStr = escapeCSV(w.name)
                let exStr = escapeCSV(s.exercise?.name ?? "")
                let setStr = "\(s.setNumber)"
                let repsStr = s.reps != nil ? "\(s.reps!)" : ""
                let weightStr = s.weight != nil ? String(format: "%.1f", s.weight!) : ""
                let rpeStr = s.rpe != nil ? String(format: "%.1f", s.rpe!) : ""
                let notesStr = escapeCSV(s.notes)
                csv += "\(dateStr),\(nameStr),\(exStr),\(setStr),\(repsStr),\(weightStr),\(rpeStr),\(notesStr)\n"
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
            var dict: [String: Any] = [:]
            dict["date"] = ISO8601DateFormatter().string(from: m.date)
            dict["chest"] = m.chest as Any
            dict["waist"] = m.waist as Any
            dict["hips"] = m.hips as Any
            dict["shoulders"] = m.shoulders as Any
            dict["neck"] = m.neck as Any
            dict["bicepLeft"] = m.bicepLeft as Any
            dict["bicepRight"] = m.bicepRight as Any
            dict["thighLeft"] = m.thighLeft as Any
            dict["thighRight"] = m.thighRight as Any
            dict["bodyFatPercent"] = m.bodyFatPercent as Any
            return dict
        }
    }

    private static func exportMeasurementsCSV(context: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<BodyMeasurement>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let measurements = try? context.fetch(descriptor), !measurements.isEmpty else { return nil }

        var csv = "Date,Chest,Waist,Hips,Shoulders,Neck,Bicep L,Bicep R,Thigh L,Thigh R,Body Fat %\n"
        for m in measurements {
            let fmt = { (v: Double?) -> String in v != nil ? String(format: "%.1f", v!) : "" }
            let dateStr = m.date.formatted(as: "yyyy-MM-dd")
            let cols = [dateStr, fmt(m.chest), fmt(m.waist), fmt(m.hips), fmt(m.shoulders), fmt(m.neck), fmt(m.bicepLeft), fmt(m.bicepRight), fmt(m.thighLeft), fmt(m.thighRight), fmt(m.bodyFatPercent)]
            csv += cols.joined(separator: ",") + "\n"
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
            var dict: [String: Any] = [:]
            dict["name"] = h.name
            dict["icon"] = h.icon
            let completionDates: [[String: String]] = (h.completions ?? []).map { c in
                ["date": ISO8601DateFormatter().string(from: c.date)]
            }
            dict["completions"] = completionDates
            return dict
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

import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let habit: Habit

    @State private var selectedDate: Date? = nil

    private var calendar: Calendar { Calendar.current }

    // 12 weeks × 7 days grid (columns=weeks left→right, rows=Sun→Sat)
    private var heatmapWeeks: [[Date?]] {
        let today = Date.now.startOfDay
        let weekday = calendar.component(.weekday, from: today) // 1=Sun
        guard let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
              let startDate = calendar.date(byAdding: .weekOfYear, value: -11, to: weekStart) else {
            return []
        }
        return (0..<12).map { w in
            guard let ws = calendar.date(byAdding: .weekOfYear, value: w, to: startDate) else { return [] }
            return (0..<7).map { d in
                guard let day = calendar.date(byAdding: .day, value: d, to: ws) else { return nil }
                return day <= today ? day : nil
            }
        }
    }

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    statsRow
                    heatmapSection
                    if !habit.earnedBadges.isEmpty { badgesSection }
                }
                .padding()
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
        // Per-day detail / note-edit sheet (item 7).
        .sheet(item: Binding(
            get: { selectedDate.map { IdentifiedDate(date: $0) } },
            set: { selectedDate = $0?.date }
        )) { wrapped in
            HabitNoteSheet(habit: habit, date: wrapped.date)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard("\(habit.currentStreak())", "Streak", "🔥")
            statCard("\(habit.longestStreak())", "Best", "🏆")
            statCard("\(Int(habit.allTimeCompletionRate() * 100))%", "Rate", "📊")
        }
    }

    private func statCard(_ value: String, _ label: String, _ emoji: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji).font(.title2)
            Text(value).font(.title2.weight(.bold)).foregroundColor(Color.ink)
            Text(label).font(.caption).foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.slateCard)
        .cornerRadius(12)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 12 Weeks")
                .font(.headline).foregroundColor(Color.ink)

            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 4) {
                    ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                        Text(d)
                            .font(.system(size: 9))
                            .foregroundColor(.slateText)
                            .frame(width: 12, height: 14)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(heatmapWeeks.indices, id: \.self) { w in
                            VStack(spacing: 4) {
                                ForEach(0..<7, id: \.self) { d in
                                    heatCell(heatmapWeeks[w][d])
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private func heatCell(_ date: Date?) -> some View {
        let completed = date.map { habit.isCompleted(on: $0) } ?? false
        let frozen = date.map { d in
            habit.freezeAppliedDates.contains { calendar.isDate($0, inSameDayAs: d) }
        } ?? false
        let hasNote = date.map { d in
            (habit.completions ?? []).contains { c in
                calendar.isDate(c.date, inSameDayAs: d) && !(c.note ?? "").isEmpty
            }
        } ?? false

        return Button {
            if let d = date { selectedDate = d }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        date == nil   ? Color.clear :
                        frozen        ? Color.blue.opacity(0.55) :
                        completed     ? Color.emerald.opacity(0.85) :
                                        Color.slateBorder.opacity(0.5)
                    )
                if hasNote {
                    // Tiny dot in the corner to signal a note exists
                    Circle()
                        .fill(Color.ink)
                        .frame(width: 3, height: 3)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges Earned").font(.headline).foregroundColor(Color.ink)
            HStack(spacing: 20) {
                ForEach(habit.earnedBadges.sorted(), id: \.self) { m in
                    VStack(spacing: 4) {
                        Text(badgeEmoji(m)).font(.largeTitle)
                        Text("\(m)-day").font(.caption2).foregroundColor(.slateText)
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private func badgeEmoji(_ milestone: Int) -> String {
        switch milestone {
        case 7:   return "🥉"
        case 30:  return "🥈"
        case 100: return "🥇"
        default:  return "⭐️"
        }
    }
}

// MARK: - Per-Day Note Sheet (Item 7)

/// Wrapper so we can use `.sheet(item:)` with a plain Date.
struct IdentifiedDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Sheet for viewing or editing the note on a habit's per-day completion.
/// Handles three states: (1) no completion for this date — offer to create
/// one with a note; (2) completion exists with no note — add one;
/// (3) completion exists with note — edit/delete.
struct HabitNoteSheet: View {
    let habit: Habit
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var noteText: String = ""
    @State private var existingCompletion: HabitCompletion?

    private var calendar: Calendar { Calendar.current }

    private var dateLabel: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    // Date header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateLabel)
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                        Text(existingCompletion == nil ? "Not completed" : "Completed")
                            .font(.caption)
                            .foregroundStyle(existingCompletion == nil ? Color.slateText : Color.emerald)
                    }

                    Text("Note")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.slateText)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color.slateCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.slateBorder, lineWidth: 1)
                        )
                        .foregroundStyle(Color.ink)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Habit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(Color.emerald)
                        .fontWeight(.semibold)
                }
            }
            .task { loadExisting() }
        }
    }

    private func loadExisting() {
        let match = (habit.completions ?? []).first { c in
            calendar.isDate(c.date, inSameDayAs: date)
        }
        existingCompletion = match
        noteText = match?.note ?? ""
    }

    /// Persist the note. If no completion exists for this day and a note was
    /// entered, creating one makes sense — a note with no completion is
    /// meaningless. If the user entered an empty note and one already exists,
    /// we preserve the completion but clear the note.
    private func save() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = existingCompletion {
            existing.note = trimmed.isEmpty ? nil : trimmed
        } else if !trimmed.isEmpty {
            let completion = HabitCompletion(date: date, note: trimmed)
            completion.habit = habit
            if habit.completions != nil {
                habit.completions!.append(completion)
            } else {
                habit.completions = [completion]
            }
            modelContext.insert(completion)
        }
        // If no existing completion and no note entered, nothing to save — just dismiss.

        try? modelContext.save()
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @State private var showingAddSheet = false
    @State private var selectedDate: Date = Date().startOfDay
    @State private var displayedMonth: Date = Date()

    private var calendar: Calendar { Calendar.current }

    private func completionRatio(for date: Date) -> Double {
        guard !habits.isEmpty else { return 0 }
        let completed = habits.filter { $0.isCompleted(on: date) }.count
        return Double(completed) / Double(habits.count)
    }

    private func colorForHabit(_ colorName: String) -> Color {
        switch colorName {
        case "emerald": return .emerald
        case "blue": return .blue
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        default: return .emerald
        }
    }

    // Generate all days for the displayed month grid
    private var monthDays: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }
        let firstWeekday = (calendar.component(.weekday, from: firstOfMonth) + 5) % 7 // Monday = 0
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        // Pad to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var selectedDateString: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            List {
                // Calendar
                calendarSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                // Selected date header
                Section {
                    Text(selectedDateString)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                }

                // Habits list
                if habits.isEmpty {
                    emptyState
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(habits) { habit in
                        habitRow(habit)
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.emerald)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddHabitSheet()
            }
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.emerald)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.emerald)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Day-of-week headers
            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
            HStack(spacing: 0) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.slateText)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = monthDays
            let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }

            ForEach(weeks.indices, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let idx = weekIndex * 7 + dayIndex
                        if idx < days.count, let date = days[idx] {
                            calendarDayCell(date: date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private func calendarDayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let ratio = completionRatio(for: date)
        let isFuture = date > Date().startOfDay

        return Button {
            selectedDate = date.startOfDay
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.emerald)
                } else if ratio >= 1.0 {
                    Circle()
                        .fill(Color.emerald.opacity(0.3))
                } else if ratio > 0 {
                    Circle()
                        .fill(Color.emerald.opacity(0.12))
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isSelected ? .white :
                        isFuture ? .slateText.opacity(0.4) :
                        isToday ? .emerald :
                        .white
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.slateText)
            Text("No habits yet")
                .font(.title3)
                .foregroundColor(.white)
            Text("Tap + to add your first habit")
                .font(.subheadline)
                .foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Habit Row

    private func completionPercentage(for habit: Habit) -> Int {
        let daysSinceCreation = max(1, calendar.dateComponents([.day], from: habit.createdAt.startOfDay, to: Date.now.startOfDay).day ?? 1)
        let completedDays = habit.completions.count
        return min(100, Int(round(Double(completedDays) / Double(daysSinceCreation) * 100)))
    }

    private func habitRow(_ habit: Habit) -> some View {
        let isCompleted = habit.isCompleted(on: selectedDate)

        return VStack(spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: habit.icon)
                    .font(.title2)
                    .foregroundColor(colorForHabit(habit.color))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        let streak = habit.currentStreak()
                        if streak > 0 {
                            Text("\u{1F525} \(streak) day streak")
                                .font(.caption)
                                .foregroundColor(.slateText)
                        }
                        Text("\(completionPercentage(for: habit))% completed")
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }
                }

                Spacer()

                Button {
                    habit.toggle(on: selectedDate, context: modelContext)
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundColor(isCompleted ? colorForHabit(habit.color) : .slateBorder)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Completion progress bar
            let pct = Double(completionPercentage(for: habit)) / 100.0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.slateBorder)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForHabit(habit.color))
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(12)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(habit)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Habit Sheet

struct AddHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "checkmark.circle"
    @State private var selectedColor = "emerald"

    private let icons = [
        "checkmark.circle", "drop.fill", "bed.double.fill",
        "figure.walk", "pill.fill", "book.fill",
        "heart.fill", "moon.fill", "leaf.fill",
        "dumbbell.fill", "cup.and.saucer.fill", "brain"
    ]

    private let colors: [(name: String, color: Color)] = [
        ("emerald", .emerald),
        ("blue", .blue),
        ("orange", .orange),
        ("pink", .pink),
        ("purple", .purple)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Habit Name")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.slateText)

                            TextField("e.g. Drink water", text: $name)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.slateCard)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }

                        // Icon picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.slateText)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .frame(width: 48, height: 48)
                                            .background(selectedIcon == icon ? Color.emerald.opacity(0.2) : Color.slateCard)
                                            .foregroundColor(selectedIcon == icon ? .emerald : .slateText)
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedIcon == icon ? Color.emerald : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.slateText)

                            HStack(spacing: 16) {
                                ForEach(colors, id: \.name) { item in
                                    Button {
                                        selectedColor = item.name
                                    } label: {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == item.name ? 3 : 0)
                                            )
                                            .overlay {
                                                if selectedColor == item.name {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.bold())
                                                        .foregroundColor(.white)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.slateText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let habit = Habit(name: name, icon: selectedIcon, color: selectedColor)
                        modelContext.insert(habit)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(.emerald)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    HabitsView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}

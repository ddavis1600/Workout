import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @State private var showingAddSheet = false
    @State private var selectedDate: Date = .now

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = Date.now.startOfDay
        let weekday = calendar.component(.weekday, from: today)
        // Monday = start of week (weekday: 2 in Gregorian)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: monday)! }
    }

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

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Weekly overview
                    weeklyOverview

                    // Habits list
                    if habits.isEmpty {
                        emptyState
                    } else {
                        habitsList
                    }

                    Spacer().frame(height: 20)
                }
                .padding()
            }
            .background(Color.slateBackground)
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

    private var weeklyOverview: some View {
        VStack(spacing: 12) {
            Text("This Week")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                    VStack(spacing: 6) {
                        Text(dayLabels[index])
                            .font(.caption2)
                            .foregroundColor(.slateText)

                        let ratio = completionRatio(for: date)
                        Circle()
                            .fill(ratio >= 1.0 ? Color.emerald : ratio > 0 ? Color.emerald.opacity(0.4) : Color.slateBorder)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if ratio >= 1.0 {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                } else if ratio > 0 {
                                    Text("\(Int(ratio * 100))%")
                                        .font(.system(size: 8).bold())
                                        .foregroundColor(.white)
                                }
                            }

                        if Calendar.current.isDateInToday(date) {
                            Circle()
                                .fill(Color.emerald)
                                .frame(width: 4, height: 4)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

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

    private var habitsList: some View {
        VStack(spacing: 12) {
            ForEach(habits) { habit in
                habitRow(habit)
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: 14) {
            Image(systemName: habit.icon)
                .font(.title2)
                .foregroundColor(colorForHabit(habit.color))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)

                let streak = habit.currentStreak()
                if streak > 0 {
                    Text("\u{1F525} \(streak) day streak")
                        .font(.caption)
                        .foregroundColor(.slateText)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    habit.toggle(on: .now, context: modelContext)
                }
            } label: {
                Image(systemName: habit.isCompleted(on: .now) ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundColor(habit.isCompleted(on: .now) ? colorForHabit(habit.color) : .slateBorder)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(12)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(habit)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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

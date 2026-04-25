import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Library

struct LibraryHabitTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: String
    let category: String
    let weeklyTarget: Int
}

private let habitLibrary: [LibraryHabitTemplate] = [
    .init(name: "Morning Stretching",    icon: "figure.flexibility",     color: "orange",  category: "Morning",    weeklyTarget: 7),
    .init(name: "Cold Shower",           icon: "drop.fill",              color: "blue",    category: "Morning",    weeklyTarget: 5),
    .init(name: "Meditate",              icon: "brain",                  color: "purple",  category: "Morning",    weeklyTarget: 7),
    .init(name: "Read 20 min",           icon: "book.fill",              color: "purple",  category: "Morning",    weeklyTarget: 5),
    .init(name: "Journal",               icon: "pencil",                 color: "orange",  category: "Morning",    weeklyTarget: 7),
    .init(name: "No Phone before 9am",   icon: "iphone.slash",           color: "pink",    category: "Morning",    weeklyTarget: 7),
    .init(name: "Strength Training",     icon: "dumbbell.fill",          color: "orange",  category: "Fitness",    weeklyTarget: 3),
    .init(name: "Walk 10k Steps",        icon: "figure.walk",            color: "emerald", category: "Fitness",    weeklyTarget: 5),
    .init(name: "Cardio 30 min",         icon: "heart.fill",             color: "pink",    category: "Fitness",    weeklyTarget: 4),
    .init(name: "Yoga",                  icon: "figure.flexibility",     color: "purple",  category: "Fitness",    weeklyTarget: 3),
    .init(name: "Drink Water",           icon: "drop.fill",              color: "blue",    category: "Nutrition",  weeklyTarget: 7),
    .init(name: "No Junk Food",          icon: "leaf.fill",              color: "emerald", category: "Nutrition",  weeklyTarget: 7),
    .init(name: "Eat Vegetables",        icon: "leaf.fill",              color: "emerald", category: "Nutrition",  weeklyTarget: 7),
    .init(name: "Take Vitamins",         icon: "pill.fill",              color: "pink",    category: "Nutrition",  weeklyTarget: 7),
    .init(name: "Coffee Limit",          icon: "cup.and.saucer.fill",    color: "orange",  category: "Nutrition",  weeklyTarget: 7),
    .init(name: "8 Hours Sleep",         icon: "bed.double.fill",        color: "blue",    category: "Recovery",   weeklyTarget: 7),
    .init(name: "Sleep by 11pm",         icon: "moon.fill",              color: "purple",  category: "Recovery",   weeklyTarget: 7),
    .init(name: "No Alcohol",            icon: "xmark.circle.fill",      color: "pink",    category: "Recovery",   weeklyTarget: 7),
    .init(name: "Foam Roll",             icon: "figure.walk",            color: "blue",    category: "Recovery",   weeklyTarget: 5),
    .init(name: "Ice Bath",              icon: "thermometer.snowflake",  color: "blue",    category: "Recovery",   weeklyTarget: 3),
]

// MARK: - Category order

private let categoryOrder = ["Morning", "Fitness", "Nutrition", "Recovery", "Custom"]
private let allCategories  = ["Morning", "Fitness", "Nutrition", "Recovery", "Custom"]

// MARK: - Milestone Celebration Sheet

struct MilestoneCelebrationSheet: View {
    let milestones: [Int]
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.4
    @State private var offset: CGFloat = 0

    private func emoji(for m: Int) -> String {
        switch m {
        case 7:   return "🥉"
        case 30:  return "🥈"
        case 100: return "🥇"
        default:  return "⭐️"
        }
    }

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(milestones.map { emoji(for: $0) }.joined())
                    .font(.system(size: 72))
                    .scaleEffect(scale)
                    .offset(y: offset)

                VStack(spacing: 8) {
                    Text("Milestone Reached!")
                        .font(.title.weight(.bold))
                        .foregroundColor(Color.ink)
                    ForEach(milestones, id: \.self) { m in
                        Text("\(m)-day streak \(emoji(for: m))")
                            .font(.title3)
                            .foregroundColor(.emerald)
                    }
                }

                Text("Keep the streak alive!")
                    .font(.subheadline)
                    .foregroundColor(.slateText)

                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .foregroundColor(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.emerald)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
            }
            .padding()

            // Floating emoji confetti
            ForEach(0..<12, id: \.self) { i in
                ConfettiPiece(
                    emoji: ["🎉","✨","🔥","🌟","💪"][i % 5],
                    xOffset: CGFloat.random(in: -160...160),
                    delay: Double(i) * 0.1
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.3)) {
                offset = -12
            }
        }
    }
}

private struct ConfettiPiece: View {
    let emoji: String
    let xOffset: CGFloat
    let delay: Double
    @State private var y: CGFloat = 400
    @State private var opacity: Double = 1

    var body: some View {
        Text(emoji)
            .font(.title)
            .offset(x: xOffset, y: y)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).delay(delay)) {
                    y = -300
                    opacity = 0
                }
            }
    }
}

// MARK: - Habit Library Sheet

struct HabitLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (LibraryHabitTemplate) -> Void

    var groupedLibrary: [(String, [LibraryHabitTemplate])] {
        let grouped = Dictionary(grouping: habitLibrary, by: \.category)
        return categoryOrder.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()
                List {
                    ForEach(groupedLibrary, id: \.0) { category, items in
                        Section(header: Text(category).foregroundColor(.slateText)) {
                            ForEach(items) { template in
                                Button {
                                    onSelect(template)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: template.icon)
                                            .font(.title3)
                                            .foregroundColor(colorValue(template.color))
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(template.name)
                                                .foregroundColor(Color.ink)
                                            Text("\(template.weeklyTarget)×/week · \(template.category)")
                                                .font(.caption)
                                                .foregroundColor(.slateText)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.emerald)
                                    }
                                }
                                .listRowBackground(Color.slateCard)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Browse Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.slateText)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - HabitsView

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @State private var showingAddSheet = false
    @State private var showingLibrary = false
    @State private var habitToEdit: Habit? = nil
    @State private var selectedDate: Date = Date().startOfDay
    @State private var displayedMonth: Date = Date()
    @State private var hkValues: [String: Double] = [:]
    @State private var editMode: EditMode = .inactive
    @State private var recapExpanded = false
    @State private var pendingMilestones: (Habit, [Int])? = nil
    @State private var showingMilestone = false
    @State private var libraryPrefill: LibraryHabitTemplate? = nil
    // Per-day note sheet (item 7)
    @State private var noteTarget: (habit: Habit, date: Date)? = nil

    private var calendar: Calendar { Calendar.current }

    private var habitsByCategory: [(String, [Habit])] {
        let grouped = Dictionary(grouping: habits, by: \.category)
        return categoryOrder.compactMap { cat in
            guard let h = grouped[cat], !h.isEmpty else { return nil }
            return (cat, h)
        }
    }

    // MARK: - Weekly Recap

    private var lastWeekStats: (hit: Int, total: Int) {
        let today = Date.now
        let weekday = calendar.component(.weekday, from: today) // 1=Sun
        let daysSinceSunday = (weekday - 1 + 7) % 7
        guard let lastSunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today.startOfDay),
              let lastMonday = calendar.date(byAdding: .day, value: -6, to: lastSunday) else {
            return (0, habits.count)
        }
        let hit = habits.filter { $0.completions(from: lastMonday, days: 7) >= $0.weeklyTarget }.count
        return (hit, habits.isEmpty ? 0 : habits.count)
    }

    private var currentWeekStats: (hit: Int, total: Int) {
        guard !habits.isEmpty else { return (0, 0) }
        let hit = habits.filter { $0.isOnTrack() }.count
        return (hit, habits.count)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Weekly recap card
                if !habits.isEmpty {
                    weeklyRecapCard
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                // Calendar
                calendarSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                Section {
                    Text(selectedDateString)
                        .font(.headline)
                        .foregroundColor(Color.ink)
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                }

                if habits.isEmpty {
                    emptyState
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(habitsByCategory, id: \.0) { category, catHabits in
                        Section {
                            ForEach(catHabits) { habit in
                                NavigationLink {
                                    HabitDetailView(habit: habit)
                                } label: {
                                    habitRow(habit)
                                }
                                .listRowBackground(Color.slateBackground)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    let isDone = habit.isCompleted(on: selectedDate)
                                    Button {
                                        completeHabit(habit, on: selectedDate)
                                    } label: {
                                        Label(
                                            isDone ? "Undo" : "Done",
                                            systemImage: isDone ? "arrow.uturn.backward" : "checkmark"
                                        )
                                    }
                                    .tint(isDone ? .orange : .emerald)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        modelContext.delete(habit)
                                        try? modelContext.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        habitToEdit = habit
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button { habitToEdit = habit } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    if habit.canApplyFreeze(forWeekOf: selectedDate) {
                                        Button {
                                            habit.applyFreeze(for: selectedDate, context: modelContext)
                                        } label: {
                                            Label("Use Streak Freeze ❄️", systemImage: "snowflake")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(habit)
                                        try? modelContext.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onMove { from, to in
                                moveHabits(in: category, from: from, to: to)
                            }
                        } header: {
                            Text(category)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.slateText)
                                .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .environment(\.editMode, $editMode)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !habits.isEmpty {
                        Button(editMode == .active ? "Done" : "Reorder") {
                            editMode = editMode == .active ? .inactive : .active
                        }
                        .foregroundColor(.emerald)
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingLibrary = true
                        } label: {
                            Image(systemName: "books.vertical.fill")
                                .foregroundColor(.emerald)
                        }
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.emerald)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddHabitSheet(prefill: libraryPrefill, totalHabits: habits.count) {
                    libraryPrefill = nil
                }
            }
            .sheet(item: $habitToEdit) { habit in
                EditHabitSheet(habit: habit)
            }
            // Note sheet (item 7) — reuses HabitNoteSheet from HabitDetailView.swift.
            .sheet(item: Binding(
                get: {
                    noteTarget.map { NoteTarget(habit: $0.habit, date: $0.date) }
                },
                set: { wrapper in
                    noteTarget = wrapper.map { ($0.habit, $0.date) }
                }
            )) { target in
                HabitNoteSheet(habit: target.habit, date: target.date)
            }
            .sheet(isPresented: $showingLibrary) {
                HabitLibrarySheet { template in
                    libraryPrefill = template
                    showingAddSheet = true
                }
            }
            .sheet(isPresented: $showingMilestone) {
                if let (_, milestones) = pendingMilestones {
                    MilestoneCelebrationSheet(milestones: milestones) {
                        showingMilestone = false
                        pendingMilestones = nil
                    }
                }
            }
            .task(id: selectedDate) { await refreshHKValues() }
        }
    }

    // MARK: - Actions

    private func completeHabit(_ habit: Habit, on date: Date) {
        let wasCompleted = habit.isCompleted(on: date)
        habit.toggle(on: date, context: modelContext)
        guard !wasCompleted else { return }
        let newMilestones = habit.newlyEarnedMilestones()
        if !newMilestones.isEmpty {
            for m in newMilestones { habit.earnedBadges.append(m) }
            try? modelContext.save()
            pendingMilestones = (habit, newMilestones)
            showingMilestone = true
        }
    }

    private func moveHabits(in category: String, from offsets: IndexSet, to destination: Int) {
        var all = Array(habits)
        let catIdxs = all.indices.filter { all[$0].category == category }
        var catHabits = catIdxs.map { all[$0] }
        catHabits.move(fromOffsets: offsets, toOffset: destination)
        for (pos, globalIdx) in catIdxs.enumerated() {
            all[globalIdx] = catHabits[pos]
        }
        for (i, habit) in all.enumerated() { habit.sortOrder = i }
        try? modelContext.save()
    }

    // MARK: - HealthKit

    private func refreshHKValues() async {
        guard HealthKitManager.shared.isAvailable else { return }
        var result: [String: Double] = [:]
        for habit in habits {
            guard let trigger = habit.healthKitTrigger else { continue }
            let value = await HealthKitManager.shared.fetchDailyValue(for: trigger, on: selectedDate)
            result[trigger] = value
        }
        hkValues = result
        guard calendar.isDateInToday(selectedDate) else { return }
        for habit in habits {
            guard let trigger = habit.healthKitTrigger, habit.healthKitThreshold > 0 else { continue }
            let value = result[trigger] ?? 0
            if value >= habit.healthKitThreshold && !habit.isCompleted(on: selectedDate) {
                completeHabit(habit, on: selectedDate)
            }
        }
    }

    // MARK: - Weekly Recap Card

    private var weeklyRecapCard: some View {
        let (hit, total) = currentWeekStats
        let (lastHit, lastTotal) = lastWeekStats

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    recapExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.slateText)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(hit)/\(total)")
                                .font(.title2.weight(.bold))
                                .foregroundColor(Color.ink)
                            Text("on track")
                                .font(.subheadline)
                                .foregroundColor(.slateText)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last week")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.slateText)
                        Text("\(lastHit)/\(lastTotal) goals hit")
                            .font(.subheadline)
                            .foregroundColor(lastHit == lastTotal && lastTotal > 0 ? Color.emerald : Color.ink)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.slateText)
                        .rotationEffect(.degrees(recapExpanded ? 180 : 0))
                        .padding(.leading, 4)
                }
                .padding()
                .background(Color.slateCard)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            if recapExpanded {
                VStack(spacing: 1) {
                    ForEach(habits) { habit in
                        let (completed, target) = habit.weeklyProgress()
                        HStack {
                            Image(systemName: habit.icon)
                                .font(.caption)
                                .foregroundColor(colorValue(habit.color))
                                .frame(width: 20)
                            Text(habit.name)
                                .font(.subheadline)
                                .foregroundColor(Color.ink)
                            Spacer()
                            Text("\(completed)/\(target) days")
                                .font(.caption)
                                .foregroundColor(completed >= target ? .emerald : .slateText)
                            if completed >= target {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.emerald)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.slateCard.opacity(0.7))
                    }
                }
                .background(Color.slateCard.opacity(0.7))
                .cornerRadius(12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Calendar

    private var monthDays: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        let firstWeekday = (calendar.component(.weekday, from: firstOfMonth) + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: displayedMonth)
    }

    private var selectedDateString: String {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: selectedDate)
    }

    private func completionRatio(for date: Date) -> Double {
        guard !habits.isEmpty else { return 0 }
        return Double(habits.filter { $0.isCompleted(on: date) }.count) / Double(habits.count)
    }

    private var calendarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left").foregroundColor(.emerald)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthYearString).font(.headline).foregroundColor(Color.ink)
                Spacer()
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right").foregroundColor(.emerald)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                    Text(d).font(.caption2.weight(.semibold)).foregroundColor(.slateText).frame(maxWidth: .infinity)
                }
            }

            let days = monthDays
            let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0+7, days.count)]) }
            ForEach(weeks.indices, id: \.self) { wi in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { di in
                        let idx = wi * 7 + di
                        if idx < days.count, let date = days[idx] {
                            calendarDayCell(date: date)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 36)
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
                if isSelected { Circle().fill(Color.emerald) }
                else if ratio >= 1.0 { Circle().fill(Color.emerald.opacity(0.3)) }
                else if ratio > 0 { Circle().fill(Color.emerald.opacity(0.12)) }
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isSelected ? Color.paper :
                        isFuture   ? Color.slateText.opacity(0.4) :
                        isToday    ? Color.emerald : Color.ink
                    )
            }
            .frame(maxWidth: .infinity).frame(height: 36).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.badge.plus").font(.system(size: 48)).foregroundColor(.slateText)
            Text("No habits yet").font(.title3).foregroundColor(Color.ink)
            Text("Tap + to add your first habit").font(.subheadline).foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    // MARK: - Habit Row

    private func completionPercentage(for habit: Habit) -> Int {
        let days = max(1, calendar.dateComponents([.day], from: habit.createdAt.startOfDay, to: Date.now.startOfDay).day ?? 1)
        return min(100, Int(round(Double((habit.completions ?? []).count) / Double(days) * 100)))
    }

    private func habitRow(_ habit: Habit) -> some View {
        let isCompleted = habit.isCompleted(on: selectedDate)
        let isHKHabit = habit.healthKitTrigger != nil
        let hkValue = hkValues[habit.healthKitTrigger ?? ""] ?? 0
        let triggerInfo = HKHabitTrigger.all.first { $0.id == habit.healthKitTrigger }
        let streak = habit.currentStreak()
        let (weekDone, weekTarget) = habit.weeklyProgress()
        let onTrack = habit.isOnTrack()

        return VStack(spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: habit.icon)
                    .font(.title2)
                    .foregroundColor(colorValue(habit.color))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(habit.name).font(.body.weight(.medium)).foregroundColor(Color.ink)
                        if isHKHabit { Image(systemName: "heart.fill").font(.caption2).foregroundColor(.pink) }
                    }

                    HStack(spacing: 8) {
                        if streak > 0 {
                            HStack(spacing: 2) {
                                Text("🔥").font(.caption)
                                Text("\(streak)").font(.caption).foregroundColor(.orange)
                            }
                        }
                        Text("\(weekDone)/\(weekTarget) this week")
                            .font(.caption)
                            .foregroundColor(onTrack ? .emerald : .slateText)
                        Text("\(completionPercentage(for: habit))%")
                            .font(.caption).foregroundColor(.slateText)
                    }

                    if isHKHabit, let info = triggerInfo, info.defaultThreshold > 0 {
                        let threshold = habit.healthKitThreshold > 0 ? habit.healthKitThreshold : info.defaultThreshold
                        Text("\(Int(hkValue)) / \(Int(threshold)) \(info.unit)")
                            .font(.caption)
                            .foregroundColor(hkValue >= threshold ? .emerald : .slateText)
                    }

                    if !habit.scheduledDays.isEmpty {
                        Text(scheduledDaysLabel(habit.scheduledDays))
                            .font(.caption2).foregroundColor(.slateBorder)
                    }
                }

                Spacer()

                // Visible note affordance (item 2 / r2 feedback).
                // Filled icon when a note already exists, outline otherwise —
                // so the note for today's date is one tap away, no long-press.
                let existingNote = (habit.completions ?? []).first {
                    calendar.isDate($0.date, inSameDayAs: selectedDate)
                }?.note
                Button {
                    noteTarget = (habit, selectedDate)
                } label: {
                    Image(systemName: (existingNote?.isEmpty == false) ? "note.text" : "square.and.pencil")
                        .font(.title3)
                        .foregroundColor((existingNote?.isEmpty == false) ? colorValue(habit.color) : .slateText)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    completeHabit(habit, on: selectedDate)
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundColor(isCompleted ? colorValue(habit.color) : .slateBorder)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isHKHabit && calendar.isDateInToday(selectedDate))
                // Long-press stays as a bonus path (also matches what a power
                // user might try).
                .contextMenu {
                    Button {
                        noteTarget = (habit, selectedDate)
                    } label: {
                        Label(
                            (existingNote?.isEmpty == false) ? "Edit Note" : "Add Note",
                            systemImage: "note.text"
                        )
                    }
                }
            }

            let pct = Double(completionPercentage(for: habit)) / 100.0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.slateBorder).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(colorValue(habit.color))
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(12)
    }

    private func scheduledDaysLabel(_ days: [Int]) -> String {
        let names = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        return days.sorted().compactMap { $0 < names.count ? names[$0] : nil }.joined(separator: "·")
    }
}

// MARK: - Color helper

func colorValue(_ name: String) -> Color {
    switch name {
    case "emerald": return .emerald
    case "blue":    return .blue
    case "orange":  return .orange
    case "pink":    return .pink
    case "purple":  return .purple
    default:        return .emerald
    }
}

// MARK: - Add Habit Sheet

struct AddHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let prefill: LibraryHabitTemplate?
    let totalHabits: Int
    let onDismissed: () -> Void

    @State private var name = ""
    @State private var selectedIcon = "checkmark.circle"
    @State private var selectedColor = "emerald"
    @State private var selectedTrigger: HKHabitTrigger?
    @State private var thresholdText = ""
    @State private var showingHKPicker = false
    @State private var scheduledDays: Set<Int> = []
    @State private var hasReminder = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var weeklyTarget = 7
    @State private var category = "Custom"
    @State private var showingIconPicker = false

    private let colors: [(String, Color)] = [
        ("emerald",.emerald),("blue",.blue),("orange",.orange),("pink",.pink),("purple",.purple)
    ]
    private let dayLabels = ["S","M","T","W","T","F","S"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        habitNameField
                        categoryPicker
                        scheduledDaysPicker
                        weeklyTargetStepper
                        reminderToggle
                        hkTriggerSection
                        iconPicker
                        colorPicker
                    }
                    .padding()
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            // HK-trigger threshold field uses .decimalPad — Done dismisses.
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismissed(); dismiss() }.foregroundColor(.slateText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(.emerald)
                }
            }
            .sheet(isPresented: $showingHKPicker) {
                HKTriggerPickerSheet(selected: $selectedTrigger, thresholdText: $thresholdText)
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
        }
        .presentationDetents([.large])
        .onAppear { applyPrefill() }
    }

    private func applyPrefill() {
        guard let p = prefill else { return }
        name = p.name
        selectedIcon = p.icon
        selectedColor = p.color
        category = p.category
        weeklyTarget = p.weeklyTarget
    }

    private func save() {
        let threshold = Double(thresholdText) ?? selectedTrigger?.defaultThreshold ?? 0
        let habit = Habit(
            name: name,
            icon: selectedIcon,
            color: selectedColor,
            healthKitTrigger: selectedTrigger?.id,
            healthKitThreshold: threshold,
            scheduledDays: Array(scheduledDays),
            reminderTime: hasReminder ? reminderTime : nil,
            weeklyTarget: weeklyTarget,
            category: category,
            sortOrder: totalHabits
        )
        modelContext.insert(habit)
        try? modelContext.save()
        if hasReminder {
            NotificationService.scheduleHabitNotification(
                habitKey: "\(Int(habit.createdAt.timeIntervalSince1970))",
                name: habit.name,
                scheduledDays: Array(scheduledDays),
                reminderTime: reminderTime
            )
        }
        onDismissed()
    }

    // MARK: - Subviews

    private var habitNameField: some View {
        field("Habit Name") {
            TextField("e.g. Drink water", text: $name)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.slateCard)
                .cornerRadius(12)
                .foregroundColor(Color.ink)
        }
    }

    private var categoryPicker: some View {
        field("Category") {
            Menu {
                ForEach(allCategories, id: \.self) { cat in
                    Button(cat) { category = cat }
                }
            } label: {
                HStack {
                    Text(category).foregroundColor(Color.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(.slateText)
                }
                .padding()
                .background(Color.slateCard)
                .cornerRadius(12)
            }
        }
    }

    private var scheduledDaysPicker: some View {
        field("Schedule (empty = every day)") {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { d in
                    Button {
                        if scheduledDays.contains(d) { scheduledDays.remove(d) }
                        else { scheduledDays.insert(d) }
                    } label: {
                        Text(dayLabels[d])
                            .font(.caption.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(scheduledDays.contains(d) ? Color.emerald : Color.slateCard)
                            .foregroundColor(scheduledDays.contains(d) ? Color.paper : Color.slateText)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var weeklyTargetStepper: some View {
        field("Weekly Goal") {
            Stepper("", value: $weeklyTarget, in: 1...7)
                .labelsHidden()
                .overlay(
                    HStack {
                        Text("\(weeklyTarget) day\(weeklyTarget == 1 ? "" : "s") / week")
                            .foregroundColor(Color.ink)
                        Spacer()
                    }
                )
                .padding()
                .background(Color.slateCard)
                .cornerRadius(12)
        }
    }

    private var reminderToggle: some View {
        field("Reminder") {
            VStack(spacing: 8) {
                Toggle("Enable reminder", isOn: $hasReminder)
                    .padding()
                    .background(Color.slateCard)
                    .cornerRadius(12)
                    .tint(.emerald)
                    .foregroundColor(Color.ink)
                if hasReminder {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .padding()
                        .background(Color.slateCard)
                        .cornerRadius(12)
                        
                }
            }
        }
    }

    private var hkTriggerSection: some View {
        field("HealthKit Trigger (optional)") {
            VStack(spacing: 8) {
                Button { showingHKPicker = true } label: {
                    HStack {
                        Image(systemName: selectedTrigger == nil ? "heart.slash" : (selectedTrigger?.icon ?? "heart.fill"))
                            .foregroundColor(selectedTrigger == nil ? .slateText : .pink)
                        Text(selectedTrigger?.displayName ?? "None — mark manually")
                            .foregroundColor(selectedTrigger == nil ? Color.slateText : Color.paper)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.slateText)
                    }
                    .padding().background(Color.slateCard).cornerRadius(12)
                }
                if let trigger = selectedTrigger {
                    HStack {
                        Text("Daily goal (\(trigger.unit))").font(.caption).foregroundColor(.slateText)
                        Spacer()
                        TextField("e.g. \(Int(trigger.defaultThreshold))", text: $thresholdText)
                            .keyboardType(.decimalPad).textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing).foregroundColor(Color.ink)
                            .frame(width: 100).padding(8).background(Color.slateCard).cornerRadius(8)
                    }
                    .padding().background(Color.slateBackground).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
                }
            }
        }
    }

    private var iconPicker: some View {
        field("Icon") {
            Button { showingIconPicker = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedIcon)
                        .font(.title2)
                        .frame(width: 48, height: 48)
                        .background(Color.emerald.opacity(0.2))
                        .foregroundColor(.emerald)
                        .cornerRadius(10)
                    Text("Tap to browse icons")
                        .font(.subheadline)
                        .foregroundColor(.slateText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.slateText)
                }
                .padding()
                .background(Color.slateCard)
                .cornerRadius(12)
            }
        }
    }

    private var colorPicker: some View {
        field("Color") {
            HStack(spacing: 16) {
                ForEach(colors, id: \.0) { name, color in
                    Button { selectedColor = name } label: {
                        Circle().fill(color).frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == name ? 3 : 0))
                            .overlay {
                                if selectedColor == name {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(Color.ink)
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Edit Habit Sheet

struct EditHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let habit: Habit

    @State private var name = ""
    @State private var selectedIcon = "checkmark.circle"
    @State private var selectedColor = "emerald"
    @State private var selectedTrigger: HKHabitTrigger?
    @State private var thresholdText = ""
    @State private var showingHKPicker = false
    @State private var scheduledDays: Set<Int> = []
    @State private var hasReminder = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var weeklyTarget = 7
    @State private var category = "Custom"
    @State private var showingIconPicker = false

    private let colors: [(String, Color)] = [
        ("emerald",.emerald),("blue",.blue),("orange",.orange),("pink",.pink),("purple",.purple)
    ]
    private let dayLabels = ["S","M","T","W","T","F","S"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        field("Habit Name") {
                            TextField("e.g. Drink water", text: $name)
                                .textFieldStyle(.plain).padding()
                                .background(Color.slateCard).cornerRadius(12).foregroundColor(Color.ink)
                        }

                        field("Category") {
                            Menu {
                                ForEach(allCategories, id: \.self) { cat in
                                    Button(cat) { category = cat }
                                }
                            } label: {
                                HStack {
                                    Text(category).foregroundColor(Color.ink)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(.slateText)
                                }
                                .padding().background(Color.slateCard).cornerRadius(12)
                            }
                        }

                        field("Schedule (empty = every day)") {
                            HStack(spacing: 6) {
                                ForEach(0..<7, id: \.self) { d in
                                    Button {
                                        if scheduledDays.contains(d) { scheduledDays.remove(d) }
                                        else { scheduledDays.insert(d) }
                                    } label: {
                                        Text(dayLabels[d])
                                            .font(.caption.weight(.semibold))
                                            .frame(width: 36, height: 36)
                                            .background(scheduledDays.contains(d) ? Color.emerald : Color.slateCard)
                                            .foregroundColor(scheduledDays.contains(d) ? Color.paper : Color.slateText)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }

                        field("Weekly Goal") {
                            Stepper("", value: $weeklyTarget, in: 1...7)
                                .labelsHidden()
                                .overlay(
                                    HStack {
                                        Text("\(weeklyTarget) day\(weeklyTarget == 1 ? "" : "s") / week")
                                            .foregroundColor(Color.ink)
                                        Spacer()
                                    }
                                )
                                .padding().background(Color.slateCard).cornerRadius(12)
                        }

                        field("Reminder") {
                            VStack(spacing: 8) {
                                Toggle("Enable reminder", isOn: $hasReminder)
                                    .padding().background(Color.slateCard).cornerRadius(12)
                                    .tint(.emerald).foregroundColor(Color.ink)
                                if hasReminder {
                                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                        .padding().background(Color.slateCard).cornerRadius(12)
                                }
                            }
                        }

                        field("HealthKit Trigger (optional)") {
                            VStack(spacing: 8) {
                                Button { showingHKPicker = true } label: {
                                    HStack {
                                        Image(systemName: selectedTrigger == nil ? "heart.slash" : (selectedTrigger?.icon ?? "heart.fill"))
                                            .foregroundColor(selectedTrigger == nil ? .slateText : .pink)
                                        Text(selectedTrigger?.displayName ?? "None — mark manually")
                                            .foregroundColor(selectedTrigger == nil ? Color.slateText : Color.paper)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.slateText)
                                    }
                                    .padding().background(Color.slateCard).cornerRadius(12)
                                }
                                if let trigger = selectedTrigger {
                                    HStack {
                                        Text("Daily goal (\(trigger.unit))").font(.caption).foregroundColor(.slateText)
                                        Spacer()
                                        TextField("e.g. \(Int(trigger.defaultThreshold))", text: $thresholdText)
                                            .keyboardType(.decimalPad).textFieldStyle(.plain)
                                            .multilineTextAlignment(.trailing).foregroundColor(Color.ink)
                                            .frame(width: 100).padding(8).background(Color.slateCard).cornerRadius(8)
                                    }
                                    .padding().background(Color.slateBackground).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
                                }
                            }
                        }

                        field("Icon") {
                            Button { showingIconPicker = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedIcon)
                                        .font(.title2)
                                        .frame(width: 48, height: 48)
                                        .background(Color.emerald.opacity(0.2))
                                        .foregroundColor(.emerald)
                                        .cornerRadius(10)
                                    Text("Tap to browse icons")
                                        .font(.subheadline)
                                        .foregroundColor(.slateText)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.slateText)
                                }
                                .padding()
                                .background(Color.slateCard)
                                .cornerRadius(12)
                            }
                        }

                        field("Color") {
                            HStack(spacing: 16) {
                                ForEach(colors, id: \.0) { cName, color in
                                    Button { selectedColor = cName } label: {
                                        Circle().fill(color).frame(width: 40, height: 40)
                                            .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == cName ? 3 : 0))
                                            .overlay {
                                                if selectedColor == cName {
                                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(Color.ink)
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
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            // HK-trigger threshold field uses .decimalPad — Done dismisses.
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.slateText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(.emerald)
                }
            }
            .sheet(isPresented: $showingHKPicker) {
                HKTriggerPickerSheet(selected: $selectedTrigger, thresholdText: $thresholdText)
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
        }
        .presentationDetents([.large])
        .onAppear { loadFromHabit() }
    }

    private func loadFromHabit() {
        name = habit.name
        selectedIcon = habit.icon
        selectedColor = habit.color
        category = habit.category
        weeklyTarget = habit.weeklyTarget
        scheduledDays = Set(habit.scheduledDays)
        if let rt = habit.reminderTime { hasReminder = true; reminderTime = rt }
        selectedTrigger = HKHabitTrigger.all.first { $0.id == habit.healthKitTrigger }
        if habit.healthKitThreshold > 0 { thresholdText = "\(Int(habit.healthKitThreshold))" }
    }

    private func save() {
        let oldKey = "\(Int(habit.createdAt.timeIntervalSince1970))"
        habit.name = name
        habit.icon = selectedIcon
        habit.color = selectedColor
        habit.category = category
        habit.weeklyTarget = weeklyTarget
        habit.scheduledDays = Array(scheduledDays)
        habit.reminderTime = hasReminder ? reminderTime : nil
        habit.healthKitTrigger = selectedTrigger?.id
        habit.healthKitThreshold = Double(thresholdText) ?? selectedTrigger?.defaultThreshold ?? 0
        try? modelContext.save()

        NotificationService.cancelHabitNotification(habitKey: oldKey)
        if hasReminder {
            NotificationService.scheduleHabitNotification(
                habitKey: oldKey,
                name: name,
                scheduledDays: Array(scheduledDays),
                reminderTime: reminderTime
            )
        }
    }
}

// MARK: - Shared field layout

@ViewBuilder
private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.subheadline.weight(.medium)).foregroundColor(.slateText)
        content()
    }
}

// MARK: - HK Trigger Picker

struct HKTriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: HKHabitTrigger?
    @Binding var thresholdText: String

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()
                List {
                    Button {
                        selected = nil; thresholdText = ""; dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.slash").frame(width: 28).foregroundColor(.slateText)
                            Text("None — mark manually").foregroundColor(Color.ink)
                            Spacer()
                            if selected == nil { Image(systemName: "checkmark").foregroundColor(.emerald) }
                        }
                    }
                    .listRowBackground(Color.slateCard)

                    ForEach(HKHabitTrigger.all) { trigger in
                        Button {
                            selected = trigger
                            if thresholdText.isEmpty { thresholdText = "\(Int(trigger.defaultThreshold))" }
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: trigger.icon).frame(width: 28).foregroundColor(.pink)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trigger.displayName).foregroundColor(Color.ink)
                                    Text("Default: \(Int(trigger.defaultThreshold)) \(trigger.unit)").font(.caption).foregroundColor(.slateText)
                                }
                                Spacer()
                                if selected?.id == trigger.id { Image(systemName: "checkmark").foregroundColor(.emerald) }
                            }
                        }
                        .listRowBackground(Color.slateCard)
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
            .navigationTitle("HealthKit Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.emerald)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Icon Picker

private struct HabitIcon: Identifiable {
    let symbol: String
    let label: String
    var id: String { symbol }
}

private struct HabitIconCategory: Identifiable {
    let name: String
    let icons: [HabitIcon]
    var id: String { name }
}

private let habitIconCategories: [HabitIconCategory] = [
    .init(name: "Fitness", icons: [
        .init(symbol: "figure.run",                          label: "Run"),
        .init(symbol: "figure.walk",                         label: "Walk"),
        .init(symbol: "figure.strengthtraining.traditional", label: "Lift"),
        .init(symbol: "figure.yoga",                         label: "Yoga"),
        .init(symbol: "figure.pool.swim",                    label: "Swim"),
        .init(symbol: "figure.outdoor.cycle",                label: "Cycle"),
        .init(symbol: "figure.hiking",                       label: "Hike"),
        .init(symbol: "figure.dance",                        label: "Dance"),
        .init(symbol: "figure.mind.and.body",                label: "Mindful"),
        .init(symbol: "figure.flexibility",                  label: "Stretch"),
        .init(symbol: "figure.martial.arts",                 label: "Martial Arts"),
        .init(symbol: "dumbbell.fill",                       label: "Weights"),
        .init(symbol: "heart.fill",                          label: "Heart Rate"),
        .init(symbol: "lungs.fill",                          label: "Breathe"),
    ]),
    .init(name: "Nutrition", icons: [
        .init(symbol: "fork.knife",                          label: "Eat"),
        .init(symbol: "leaf.fill",                           label: "Greens"),
        .init(symbol: "cup.and.saucer.fill",                 label: "Coffee"),
        .init(symbol: "mug.fill",                            label: "Hot Drink"),
        .init(symbol: "waterbottle.fill",                    label: "Water Bottle"),
        .init(symbol: "drop.fill",                           label: "Hydrate"),
        .init(symbol: "takeoutbag.and.cup.and.straw.fill",   label: "Meals"),
        .init(symbol: "flame.fill",                          label: "Calories"),
    ]),
    .init(name: "Sleep", icons: [
        .init(symbol: "bed.double.fill",                     label: "Sleep"),
        .init(symbol: "moon.fill",                           label: "Night"),
        .init(symbol: "moon.zzz.fill",                       label: "Rest"),
        .init(symbol: "moon.stars.fill",                     label: "Bedtime"),
        .init(symbol: "zzz",                                 label: "Nap"),
        .init(symbol: "alarm.fill",                          label: "Wake Up"),
    ]),
    .init(name: "Mind", icons: [
        .init(symbol: "brain.head.profile",                  label: "Focus"),
        .init(symbol: "brain",                               label: "Think"),
        .init(symbol: "book.fill",                           label: "Read"),
        .init(symbol: "books.vertical.fill",                 label: "Study"),
        .init(symbol: "pencil",                              label: "Write"),
        .init(symbol: "graduationcap.fill",                  label: "Learn"),
        .init(symbol: "lightbulb.fill",                      label: "Ideas"),
        .init(symbol: "sparkles",                            label: "Creative"),
    ]),
    .init(name: "Productivity", icons: [
        .init(symbol: "checklist",                           label: "To-Do"),
        .init(symbol: "checkmark.circle.fill",               label: "Complete"),
        .init(symbol: "checkmark.circle",                    label: "Done"),
        .init(symbol: "calendar",                            label: "Schedule"),
        .init(symbol: "clock.fill",                          label: "Time"),
        .init(symbol: "hourglass",                           label: "Timer"),
        .init(symbol: "timer",                               label: "Countdown"),
        .init(symbol: "target",                              label: "Goals"),
        .init(symbol: "flag.fill",                           label: "Milestone"),
        .init(symbol: "iphone.slash",                        label: "Screen Time"),
    ]),
    .init(name: "Social", icons: [
        .init(symbol: "person.2.fill",                       label: "Friends"),
        .init(symbol: "phone.fill",                          label: "Call"),
        .init(symbol: "envelope.fill",                       label: "Email"),
        .init(symbol: "message.fill",                        label: "Message"),
        .init(symbol: "hand.wave.fill",                      label: "Connect"),
        .init(symbol: "gift.fill",                           label: "Give"),
        .init(symbol: "heart.text.square.fill",              label: "Gratitude"),
    ]),
    .init(name: "Home", icons: [
        .init(symbol: "house.fill",                          label: "Home"),
        .init(symbol: "cart.fill",                           label: "Shopping"),
        .init(symbol: "trash.fill",                          label: "Clean"),
        .init(symbol: "bag.fill",                            label: "Errands"),
        .init(symbol: "washer.fill",                         label: "Laundry"),
        .init(symbol: "fork.knife.circle.fill",              label: "Cook"),
        .init(symbol: "archivebox.fill",                     label: "Organize"),
    ]),
    .init(name: "Finance", icons: [
        .init(symbol: "dollarsign.circle.fill",              label: "Budget"),
        .init(symbol: "creditcard.fill",                     label: "Spending"),
        .init(symbol: "chart.line.uptrend.xyaxis",           label: "Growth"),
        .init(symbol: "banknote.fill",                       label: "Cash"),
        .init(symbol: "chart.bar.fill",                      label: "Stats"),
        .init(symbol: "arrow.up.arrow.down.circle.fill",     label: "Savings"),
    ]),
    .init(name: "Hobbies", icons: [
        .init(symbol: "music.note",                          label: "Music"),
        .init(symbol: "guitars.fill",                        label: "Guitar"),
        .init(symbol: "camera.fill",                         label: "Photography"),
        .init(symbol: "paintbrush.fill",                     label: "Paint"),
        .init(symbol: "gamecontroller.fill",                 label: "Gaming"),
        .init(symbol: "theatermasks",                        label: "Theater"),
        .init(symbol: "film.fill",                           label: "Film"),
        .init(symbol: "photo.fill",                          label: "Photos"),
        .init(symbol: "pencil.and.ruler",                    label: "Design"),
    ]),
    .init(name: "Outdoors", icons: [
        .init(symbol: "sun.max.fill",                        label: "Sunny"),
        .init(symbol: "cloud.sun.fill",                      label: "Outside"),
        .init(symbol: "snowflake",                           label: "Cold"),
        .init(symbol: "airplane",                            label: "Travel"),
        .init(symbol: "car.fill",                            label: "Drive"),
        .init(symbol: "bicycle",                             label: "Bike"),
        .init(symbol: "map.fill",                            label: "Navigate"),
        .init(symbol: "binoculars.fill",                     label: "Explore"),
        .init(symbol: "tent.fill",                           label: "Camp"),
    ]),
    .init(name: "Wellness", icons: [
        .init(symbol: "pills.fill",                          label: "Medication"),
        .init(symbol: "pill.fill",                           label: "Pill"),
        .init(symbol: "cross.case.fill",                     label: "First Aid"),
        .init(symbol: "stethoscope",                         label: "Health"),
        .init(symbol: "eye.fill",                            label: "Vision"),
        .init(symbol: "hand.raised.fill",                    label: "Self-Care"),
        .init(symbol: "bandage.fill",                        label: "Recovery"),
        .init(symbol: "figure.cooldown",                     label: "Cool Down"),
    ]),
    .init(name: "Reflection", icons: [
        .init(symbol: "sun.horizon.fill",                    label: "Sunrise"),
        .init(symbol: "hands.sparkles",                      label: "Gratitude"),
        .init(symbol: "star.fill",                           label: "Achievement"),
        .init(symbol: "bolt.fill",                           label: "Energy"),
        .init(symbol: "text.bubble.fill",                    label: "Journal"),
    ]),
]

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedCategory = "All"

    private var categoryNames: [String] {
        ["All"] + habitIconCategories.map(\.name)
    }

    private var filteredIcons: [HabitIcon] {
        let base: [HabitIcon]
        if selectedCategory == "All" {
            base = habitIconCategories.flatMap(\.icons)
        } else {
            base = habitIconCategories.first { $0.name == selectedCategory }?.icons ?? []
        }
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter { $0.label.lowercased().contains(q) || $0.symbol.lowercased().contains(q) }
    }

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryScrollView
                Divider()
                iconGridView
            }
            .background(Color.slateBackground)
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search icons")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.emerald)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryNames, id: \.self) { cat in
                    Button(cat) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = cat
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedCategory == cat ? Color.emerald : Color(.systemGray5))
                    .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var iconGridView: some View {
        ScrollView {
            if filteredIcons.isEmpty {
                ContentUnavailableView(
                    "No icons found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredIcons) { icon in
                        iconCell(icon)
                    }
                }
                .padding(16)
            }
        }
    }

    private func iconCell(_ entry: HabitIcon) -> some View {
        let isSelected = selectedIcon == entry.symbol
        return Button {
            selectedIcon = entry.symbol
        } label: {
            VStack(spacing: 4) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                Text(entry.label)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 68, height: 76)
            .background(isSelected ? Color.emerald.opacity(0.2) : Color.slateCard)
            .foregroundStyle(isSelected ? Color.emerald : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.emerald : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HabitsView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}

// MARK: - Note-sheet target wrapper (item 7)
// `.sheet(item:)` requires an Identifiable, and a bare tuple isn't one.
private struct NoteTarget: Identifiable {
    let habit: Habit
    let date: Date
    var id: String { "\(habit.persistentModelID)-\(date.timeIntervalSince1970)" }
}

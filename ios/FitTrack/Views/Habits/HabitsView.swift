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
                        .foregroundColor(.white)
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
                        .foregroundColor(.white)
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
                                                .foregroundColor(.white)
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
                        .foregroundColor(.white)
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
                                    Button {
                                        completeHabit(habit, on: selectedDate)
                                    } label: {
                                        Label(
                                            habit.isCompleted(on: selectedDate) ? "Undo" : "Done",
                                            systemImage: habit.isCompleted(on: selectedDate) ? "arrow.uturn.backward" : "checkmark"
                                        )
                                    }
                                    .tint(habit.isCompleted(on: selectedDate) ? .orange : .emerald)
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
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Habits")
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
                                .foregroundColor(.white)
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
                            .foregroundColor(lastHit == lastTotal && lastTotal > 0 ? .emerald : .white)
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
                                .foregroundColor(.white)
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
                Text(monthYearString).font(.headline).foregroundColor(.white)
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
                        isSelected ? .white :
                        isFuture   ? .slateText.opacity(0.4) :
                        isToday    ? .emerald : .white
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
            Text("No habits yet").font(.title3).foregroundColor(.white)
            Text("Tap + to add your first habit").font(.subheadline).foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    // MARK: - Habit Row

    private func completionPercentage(for habit: Habit) -> Int {
        let days = max(1, calendar.dateComponents([.day], from: habit.createdAt.startOfDay, to: Date.now.startOfDay).day ?? 1)
        return min(100, Int(round(Double(habit.completions.count) / Double(days) * 100)))
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
                        Text(habit.name).font(.body.weight(.medium)).foregroundColor(.white)
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

    private let icons = [
        "checkmark.circle", "drop.fill", "bed.double.fill",
        "figure.walk", "pill.fill", "book.fill",
        "heart.fill", "moon.fill", "leaf.fill",
        "dumbbell.fill", "cup.and.saucer.fill", "brain",
        "figure.flexibility", "iphone.slash", "snowflake",
        "pencil", "star.fill", "bolt.fill"
    ]
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
                .foregroundColor(.white)
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
                    Text(category).foregroundColor(.white)
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
                            .foregroundColor(scheduledDays.contains(d) ? .white : .slateText)
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
                            .foregroundColor(.white)
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
                    .foregroundColor(.white)
                if hasReminder {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .padding()
                        .background(Color.slateCard)
                        .cornerRadius(12)
                        .colorScheme(.dark)
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
                            .foregroundColor(selectedTrigger == nil ? .slateText : .white)
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
                            .multilineTextAlignment(.trailing).foregroundColor(.white)
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(icons, id: \.self) { icon in
                    Button { selectedIcon = icon } label: {
                        Image(systemName: icon).font(.title2)
                            .frame(width: 48, height: 48)
                            .background(selectedIcon == icon ? Color.emerald.opacity(0.2) : Color.slateCard)
                            .foregroundColor(selectedIcon == icon ? .emerald : .slateText)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedIcon == icon ? Color.emerald : Color.clear, lineWidth: 2))
                    }
                }
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
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(.white)
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

    private let icons = [
        "checkmark.circle", "drop.fill", "bed.double.fill",
        "figure.walk", "pill.fill", "book.fill",
        "heart.fill", "moon.fill", "leaf.fill",
        "dumbbell.fill", "cup.and.saucer.fill", "brain",
        "figure.flexibility", "iphone.slash", "snowflake",
        "pencil", "star.fill", "bolt.fill"
    ]
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
                                .background(Color.slateCard).cornerRadius(12).foregroundColor(.white)
                        }

                        field("Category") {
                            Menu {
                                ForEach(allCategories, id: \.self) { cat in
                                    Button(cat) { category = cat }
                                }
                            } label: {
                                HStack {
                                    Text(category).foregroundColor(.white)
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
                                            .foregroundColor(scheduledDays.contains(d) ? .white : .slateText)
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
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                )
                                .padding().background(Color.slateCard).cornerRadius(12)
                        }

                        field("Reminder") {
                            VStack(spacing: 8) {
                                Toggle("Enable reminder", isOn: $hasReminder)
                                    .padding().background(Color.slateCard).cornerRadius(12)
                                    .tint(.emerald).foregroundColor(.white)
                                if hasReminder {
                                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                        .padding().background(Color.slateCard).cornerRadius(12).colorScheme(.dark)
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
                                            .foregroundColor(selectedTrigger == nil ? .slateText : .white)
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
                                            .multilineTextAlignment(.trailing).foregroundColor(.white)
                                            .frame(width: 100).padding(8).background(Color.slateCard).cornerRadius(8)
                                    }
                                    .padding().background(Color.slateBackground).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
                                }
                            }
                        }

                        field("Icon") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button { selectedIcon = icon } label: {
                                        Image(systemName: icon).font(.title2)
                                            .frame(width: 48, height: 48)
                                            .background(selectedIcon == icon ? Color.emerald.opacity(0.2) : Color.slateCard)
                                            .foregroundColor(selectedIcon == icon ? .emerald : .slateText)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedIcon == icon ? Color.emerald : Color.clear, lineWidth: 2))
                                    }
                                }
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
                                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(.white)
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
                            Text("None — mark manually").foregroundColor(.white)
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
                                    Text(trigger.displayName).foregroundColor(.white)
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

#Preview {
    HabitsView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}

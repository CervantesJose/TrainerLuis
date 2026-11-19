import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    // The secondary sort keeps a day's several workouts in a stable, add-order sequence
    // rather than whatever the store happens to return for the tie.
    @Query(sort: [SortDescriptor(\Workout.date), SortDescriptor(\Workout.createdAt)])
    private var workouts: [Workout]

    @State private var currentMonth = Date()
    @State private var selectedDate: Date = Date()
    @State private var showingCreate = false
    @State private var duplicating: Workout?

    private let cal = Calendar.current
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// A day can hold several sessions, so the selection maps to a list.
    private var selectedWorkouts: [Workout] {
        dayWorkouts(on: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarHeader
                selectedDayContent
            }
            .navigationTitle("Calendar")
            // The month grid is pinned above a scrolling list. A large title resizes as that
            // list scrolls, which changed the safe area and dragged the title and rows in and
            // out from under the grid; an inline title keeps the layout fixed. The explicit
            // bar background stops list rows showing through the toolbar as they pass under it.
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Workout", systemImage: "plus") {
                        showingCreate = true
                    }
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .sheet(isPresented: $showingCreate) {
                CreateWorkoutView(initialDate: selectedDate)
            }
            .sheet(item: $duplicating) { workout in
                // Copying from an empty day means "put it here", so open on that day. Copying
                // off a day that already has workouts is about moving it elsewhere, so let the
                // sheet fall back to its own default.
                DuplicateWorkoutView(
                    source: workout,
                    initialDate: selectedWorkouts.isEmpty ? selectedDate : nil
                )
            }
        }
    }

    // MARK: Sub-views

    /// The fixed part of the screen. It carries its own background so the list scrolling
    /// below can never be seen through the grid.
    private var calendarHeader: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeader
            calendarGrid
            Divider()
        }
        .background(.background)
    }

    private var monthHeader: some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") {
                currentMonth = cal.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }
            .labelStyle(.iconOnly)
            .font(.title2.weight(.semibold))
            .frame(width: 44, height: 44)

            Spacer()

            Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())

            Spacer()

            Button("Next Month", systemImage: "chevron.right") {
                currentMonth = cal.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }
            .labelStyle(.iconOnly)
            .font(.title2.weight(.semibold))
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private var calendarGrid: some View {
        // Bucketed once rather than rescanning every workout for each of the 42 cells.
        let byDay = workoutsByDay

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
            ForEach(daysInMonth().enumerated(), id: \.offset) { _, date in
                if let date {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = date
                        }
                    } label: {
                        DayCell(
                            date: date,
                            isSelected: cal.isDate(selectedDate, inSameDayAs: date),
                            isToday: cal.isDateInToday(date),
                            dotColors: (byDay[cal.startOfDay(for: date)] ?? []).map(dotColor)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 50)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var selectedDayContent: some View {
        let dayWorkouts = selectedWorkouts

        if dayWorkouts.isEmpty {
            emptyDay
        } else {
            List {
                Section {
                    ForEach(dayWorkouts) { workout in
                        workoutRow(workout)
                    }
                    .onDelete { offsets in
                        delete(at: offsets, from: dayWorkouts)
                    }

                    Button {
                        showingCreate = true
                    } label: {
                        Label("Add Another Workout", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                } footer: {
                    Text("Swipe a workout left to delete it, right to copy it to another day.")
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func workoutRow(_ workout: Workout) -> some View {
        NavigationLink(value: workout) {
            WorkoutRow(workout: workout)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                duplicating = workout
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.accentColor)
        }
        .contextMenu {
            Button {
                duplicating = workout
            } label: {
                Label("Duplicate to…", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                delete(workout)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyDay: some View {
        ContentUnavailableView {
            Label(
                "No workout on \(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))",
                systemImage: "calendar.badge.plus"
            )
        } actions: {
            Button("Add Workout") {
                showingCreate = true
            }
            .buttonStyle(.borderedProminent)

            if let recent = mostRecentWorkout {
                Button("Copy \(recent.name)") {
                    duplicating = recent
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Helpers

    private func daysInMonth() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return [] }
        let firstDay = interval.start
        let leadingBlanks = cal.component(.weekday, from: firstDay) - 1
        let dayCount = cal.range(of: .day, in: .month, for: currentMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            days.append(cal.date(byAdding: .day, value: offset, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    /// Every workout keyed by its day, each day's workouts in the order they were added.
    private var workoutsByDay: [Date: [Workout]] {
        Dictionary(grouping: workouts) { cal.startOfDay(for: $0.date) }
            .mapValues { $0.sorted { $0.createdAt < $1.createdAt } }
    }

    private func dayWorkouts(on date: Date) -> [Workout] {
        workouts
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// The latest workout at or before the selected day — the most likely thing to copy.
    private var mostRecentWorkout: Workout? {
        workouts.last { $0.date <= selectedDate && !$0.workoutExercises.isEmpty }
            ?? workouts.first { !$0.workoutExercises.isEmpty }
    }

    private func dotColor(for workout: Workout) -> Color {
        workout.isCompleted ? .green : .orange
    }

    private func delete(_ workout: Workout) {
        modelContext.delete(workout)
        modelContext.saveChanges()
    }

    private func delete(at offsets: IndexSet, from dayWorkouts: [Workout]) {
        for index in offsets {
            modelContext.delete(dayWorkouts[index])
        }
        modelContext.saveChanges()
    }
}

#if DEBUG

#Preview {
    CalendarView()
        .modelContainer(PreviewData.container)
}

#endif

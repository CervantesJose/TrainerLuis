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

    /// A day can hold several sessions, so the selection maps to a list.
    private var selectedWorkouts: [Workout] {
        dayWorkouts(on: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarHeader(
                    currentMonth: $currentMonth,
                    selectedDate: $selectedDate,
                    workoutsByDay: workoutsByDay
                )

                let dayWorkouts = selectedWorkouts
                if dayWorkouts.isEmpty {
                    EmptyDayView(
                        date: selectedDate,
                        mostRecentWorkout: mostRecentWorkout,
                        onAdd: { showingCreate = true },
                        onCopy: { duplicating = $0 }
                    )
                } else {
                    DayWorkoutsList(
                        date: selectedDate,
                        workouts: dayWorkouts,
                        onAdd: { showingCreate = true },
                        onDuplicate: { duplicating = $0 },
                        onDelete: delete
                    )
                }
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

    // MARK: Helpers

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

    private func delete(_ workouts: [Workout]) {
        for workout in workouts {
            modelContext.delete(workout)
        }
        modelContext.saveChanges()
    }
}

// MARK: - Subviews

/// The fixed part of the screen. It carries its own background so the list scrolling
/// below can never be seen through the grid.
private struct CalendarHeader: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let workoutsByDay: [Date: [Workout]]

    var body: some View {
        VStack {
            MonthHeader(currentMonth: $currentMonth)
            WeekdayHeader()
            CalendarGrid(month: currentMonth, selectedDate: $selectedDate, workoutsByDay: workoutsByDay)
            Divider()
        }
        .background(.background)
    }
}

private struct MonthHeader: View {
    @Binding var currentMonth: Date

    private let cal = Calendar.current

    var body: some View {
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
    }
}

private struct WeekdayHeader: View {
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
}

private struct CalendarGrid: View {
    let month: Date
    @Binding var selectedDate: Date

    /// Bucketed once by the caller rather than rescanning every workout for each of the 42 cells.
    let workoutsByDay: [Date: [Workout]]

    private let cal = Calendar.current

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
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
                            dotColors: (workoutsByDay[cal.startOfDay(for: date)] ?? []).map(dotColor)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 50)
                }
            }
        }
        // Same inset as the weekday header, so each column sits under its label.
        .padding(.horizontal)
    }

    private func daysInMonth() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = interval.start
        let leadingBlanks = cal.component(.weekday, from: firstDay) - 1
        let dayCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            days.append(cal.date(byAdding: .day, value: offset, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func dotColor(for workout: Workout) -> Color {
        workout.isCompleted ? .green : .orange
    }
}

/// The selected day's workouts, when it has any.
private struct DayWorkoutsList: View {
    let date: Date
    let workouts: [Workout]
    let onAdd: () -> Void
    let onDuplicate: (Workout) -> Void
    let onDelete: ([Workout]) -> Void

    var body: some View {
        List {
            Section {
                ForEach(workouts) { workout in
                    NavigationLink(value: workout) {
                        WorkoutRow(workout: workout)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("Duplicate", systemImage: "doc.on.doc") {
                            onDuplicate(workout)
                        }
                        .tint(.accentColor)
                    }
                    .contextMenu {
                        Button("Duplicate to…", systemImage: "doc.on.doc") {
                            onDuplicate(workout)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            onDelete([workout])
                        }
                    }
                }
                .onDelete { offsets in
                    onDelete(offsets.map { workouts[$0] })
                }

                Button("Add Another Workout", systemImage: "plus.circle.fill", action: onAdd)
            } header: {
                Text(date.formatted(.dateTime.weekday(.wide).month().day()))
            } footer: {
                Text("Swipe a workout left to delete it, right to copy it to another day.")
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct EmptyDayView: View {
    let date: Date

    /// The most likely workout to copy onto this day, if there is one.
    let mostRecentWorkout: Workout?
    let onAdd: () -> Void
    let onCopy: (Workout) -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                "No workout on \(date.formatted(.dateTime.weekday(.wide).month().day()))",
                systemImage: "calendar.badge.plus"
            )
        } actions: {
            Button("Add Workout", action: onAdd)
                .buttonStyle(.borderedProminent)

            if let recent = mostRecentWorkout {
                Button("Copy \(recent.name)") {
                    onCopy(recent)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#if DEBUG

#Preview {
    CalendarView()
        .modelContainer(PreviewData.container)
}

#endif

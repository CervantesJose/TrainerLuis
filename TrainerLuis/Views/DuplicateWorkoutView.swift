import SwiftUI
import SwiftData

/// Copies an existing workout onto another day.
///
/// This is how templates work: reusing a session means duplicating it. Name, notes, exercises,
/// per-workout sets/reps and superset grouping all come across; completion state does not.
struct DuplicateWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let source: Workout

    /// The day to open on. `nil` defaults to the day after the source, which is the usual
    /// "do this again next time" case.
    var initialDate: Date?

    @State private var name = ""
    @State private var date = Date()

    /// The target day's existing workouts, so the copy landing alongside them is visible
    /// before it happens.
    @State private var sameDay: [Workout] = []
    @State private var hasLoaded = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var canCopy: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout Name", text: $name)
                        .autocorrectionDisabled()

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("New Workout")
                } footer: {
                    if sameDay.isEmpty {
                        Text("Copied from “\(source.name)” on \(source.date.formatted(date: .abbreviated, time: .omitted)).")
                    } else {
                        Text("Already on \(date.formatted(.dateTime.month().day())): \(sameDay.map(\.name).formatted(.list(type: .and))). The copy will be added alongside \(sameDay.count == 1 ? "it" : "them").")
                    }
                }

                Section {
                    ForEach(source.blocks) { block in
                        WorkoutBlockView(block: block)
                    }
                } header: {
                    Text("Copying")
                } footer: {
                    Text(source.summary)
                }
            }
            .navigationTitle("Duplicate Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") { copy() }
                        .disabled(!canCopy)
                }
            }
            .onAppear(perform: load)
            .onChange(of: date) { _, _ in refreshSameDay() }
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        name = source.name

        let calendar = Calendar.current
        if let initialDate {
            date = calendar.startOfDay(for: initialDate)
        } else {
            // The day after the source — but never in the past, since copying an old workout
            // is nearly always about scheduling it again now.
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: source.date) ?? source.date
            date = max(tomorrow, calendar.startOfDay(for: Date()))
        }

        refreshSameDay()
    }

    private func refreshSameDay() {
        sameDay = Workout.workouts(on: date, in: modelContext)
    }

    private func copy() {
        guard canCopy else { return }

        source.duplicate(to: date, named: trimmedName, in: modelContext)
        modelContext.saveChanges()
        dismiss()
    }
}

#if DEBUG

#Preview {
    DuplicateWorkoutView(source: PreviewData.workout)
        .modelContainer(PreviewData.container)
}

#endif

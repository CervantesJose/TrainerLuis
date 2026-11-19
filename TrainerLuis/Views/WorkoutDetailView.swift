import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout

    @State private var showingEditWorkout = false
    @State private var showingDuplicate = false

    /// The slot whose countdown is on screen.
    @State private var timerSlot: WorkoutExercise?

    /// Pushed for a timed row's "Exercise Details", which can't use a `NavigationLink`
    /// because the row's own tap starts the timer.
    @State private var detailExercise: Exercise?

    /// The superset whose combined screen is pushed. Held as the group id rather than the
    /// block so the pushed screen re-resolves its members after an edit.
    @State private var detailSupersetID: UUID?

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            workout.date.formatted(date: .complete, time: .omitted),
                            systemImage: "calendar"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Label(workout.summary, systemImage: "list.bullet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation { workout.isCompleted.toggle() }
                        modelContext.saveChanges()
                    } label: {
                        completionBadge
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(workout.isCompleted ? "Mark Incomplete" : "Mark Complete")
                }
                .padding(.vertical, 4)
            }

            Section {
                if workout.workoutExercises.isEmpty {
                    Button {
                        showingEditWorkout = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus.circle.fill")
                    }
                } else {
                    // Read-only here: all structural editing — sets, measures, supersets,
                    // order — happens in the one editor, so there's a single place it can go
                    // wrong. Running a timer isn't editing: it records what was performed,
                    // which is the one thing that belongs on this screen.
                    ForEach(workout.blocks) { block in
                        WorkoutBlockView(
                            block: block,
                            showsNavigation: true,
                            onStartTimer: { timerSlot = $0 },
                            onShowDetails: { detailExercise = $0 },
                            onOpenSuperset: { detailSupersetID = $0 }
                        )
                    }
                }
            } header: {
                Text("Exercises")
            } footer: {
                if !workout.workoutExercises.isEmpty {
                    Button {
                        showingEditWorkout = true
                    } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        withAnimation { workout.isCompleted.toggle() }
                        modelContext.saveChanges()
                    } label: {
                        Label(
                            workout.isCompleted ? "Mark Incomplete" : "Mark Complete",
                            systemImage: workout.isCompleted ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                    Button {
                        showingEditWorkout = true
                    } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }
                    Button {
                        showingDuplicate = true
                    } label: {
                        Label("Duplicate to…", systemImage: "doc.on.doc")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            CreateWorkoutView(workout: workout)
        }
        .sheet(isPresented: $showingDuplicate) {
            DuplicateWorkoutView(source: workout)
        }
        .sheet(item: $timerSlot) { slot in
            SetTimerView(slot: slot)
        }
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .navigationDestination(item: $detailExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .navigationDestination(item: $detailSupersetID) { groupID in
            SupersetDetailView(workout: workout, supersetID: groupID)
        }
    }

    private var completionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "circle")
            Text(workout.isCompleted ? "Done" : "Pending")
                .font(.caption.bold())
        }
        .foregroundStyle(workout.isCompleted ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((workout.isCompleted ? Color.green : Color.orange).opacity(0.15), in: .capsule)
    }
}

#if DEBUG

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: PreviewData.workout)
    }
    .modelContainer(PreviewData.container)
}

#endif

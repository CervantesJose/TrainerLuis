import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout

    @State private var showingEditWorkout = false
    @State private var showingDuplicate = false

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
                    completionBadge
                        .onTapGesture {
                            withAnimation { workout.isCompleted.toggle() }
                            modelContext.saveChanges()
                        }
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
                    // Read-only here: all structural editing — sets, reps, supersets, order —
                    // happens in the one editor, so there's a single place it can go wrong.
                    ForEach(workout.blocks) { block in
                        WorkoutBlockView(block: block, showsNavigation: true)
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
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            CreateWorkoutView(workout: workout)
        }
        .sheet(isPresented: $showingDuplicate) {
            DuplicateWorkoutView(source: workout)
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
        .background(
            Capsule().fill((workout.isCompleted ? Color.green : Color.orange).opacity(0.15))
        )
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

import SwiftUI
import SwiftData

// MARK: - Copy-From Picker

/// Picks an existing workout to seed a new one from. Every workout doubles as a template.
struct WorkoutSourcePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Workout.date, order: .reverse), SortDescriptor(\Workout.createdAt)])
    private var workouts: [Workout]

    var excluding: Workout?
    var onPick: (Workout) -> Void

    private var candidates: [Workout] {
        workouts.filter {
            $0.persistentModelID != excluding?.persistentModelID && !$0.workoutExercises.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Copy",
                        systemImage: "doc.on.doc",
                        description: Text("Once you've built a workout with exercises, you can reuse it here.")
                    )
                } else {
                    List(candidates) { source in
                        Button {
                            onPick(source)
                            dismiss()
                        } label: {
                            WorkoutRow(workout: source)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Copy From")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG

#Preview("Populated") {
    WorkoutSourcePickerView { picked in
        print("picked \(picked.name)")
    }
    .modelContainer(PreviewData.container)
}

#Preview("Nothing to copy") {
    WorkoutSourcePickerView { _ in }
        .modelContainer(PreviewData.emptyContainer)
}

#endif

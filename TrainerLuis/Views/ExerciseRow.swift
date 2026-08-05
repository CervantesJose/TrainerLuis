import SwiftUI

/// One exercise line. `sets`/`reps` override the library defaults when the row is showing an
/// exercise inside a specific workout.
struct ExerciseRow: View {
    let exercise: Exercise?
    var sets: Int?
    var reps: Int?
    /// Marks the numbers as library defaults rather than a workout's actual prescription.
    var showsDefaultHint: Bool = false

    var body: some View {
        if let exercise {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("\(sets ?? exercise.sets) sets", systemImage: "arrow.triangle.2.circlepath")
                    Label("\(reps ?? exercise.reps) reps", systemImage: "repeat")
                    if showsDefaultHint {
                        Text("default")
                            .foregroundStyle(.tertiary)
                    }
                    if exercise.videoURL != nil {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        } else {
            Text("Exercise removed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
        }
    }
}

#if DEBUG

#Preview("Variants") {
    List {
        Section("Library defaults") {
            ForEach(PreviewData.exercises.prefix(3)) { exercise in
                ExerciseRow(exercise: exercise, showsDefaultHint: true)
            }
        }
        Section("Inside a workout — per-workout values") {
            ForEach(PreviewData.workout.sortedExercises) { slot in
                ExerciseRow(exercise: slot.exercise, sets: slot.sets, reps: slot.reps)
            }
        }
        Section("Exercise deleted from the library") {
            ExerciseRow(exercise: nil)
        }
    }
    .modelContainer(PreviewData.container)
}

#endif

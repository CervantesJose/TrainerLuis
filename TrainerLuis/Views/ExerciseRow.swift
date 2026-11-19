import SwiftUI

/// One exercise line: name, plus the prescription that applies in the row's context.
///
/// The prescription arrives pre-formatted rather than as loose sets/reps, because what belongs
/// on the line differs by measure — "4 × 8", "3 × 0:15", "15:00", or nothing at all for a
/// warm-up. ``Exercise`` and ``WorkoutExercise`` each expose their own `prescription`, so the
/// row never has to know which scope it's showing.
struct ExerciseRow: View {
    let exercise: Exercise?

    /// Pre-formatted set/measure line. nil prints nothing — correct for "roll out body".
    var prescription: String?

    /// Swaps the leading glyph to a timer, marking a row whose sets can be counted down.
    var isTimed: Bool = false

    /// Marks the numbers as library defaults rather than a workout's actual prescription.
    var showsDefaultHint: Bool = false

    /// e.g. "2 of 3 done" — only present once a set has actually been performed.
    var progressText: String?

    var isComplete: Bool = false

    init(
        exercise: Exercise?,
        prescription: String? = nil,
        isTimed: Bool = false,
        showsDefaultHint: Bool = false,
        progressText: String? = nil,
        isComplete: Bool = false
    ) {
        self.exercise = exercise
        self.prescription = prescription
        self.isTimed = isTimed
        self.showsDefaultHint = showsDefaultHint
        self.progressText = progressText
        self.isComplete = isComplete
    }

    /// The row as it reads inside a workout, including any set progress recorded by the timer.
    init(slot: WorkoutExercise) {
        self.init(
            exercise: slot.exercise,
            prescription: slot.prescription,
            isTimed: slot.isTimed,
            progressText: slot.progressText,
            isComplete: slot.isComplete
        )
    }

    /// The row as it reads in the library, where the numbers are only starting values.
    init(library exercise: Exercise) {
        self.init(
            exercise: exercise,
            prescription: exercise.prescription,
            isTimed: exercise.isTimed,
            showsDefaultHint: true
        )
    }

    var body: some View {
        if let exercise {
            VStack(alignment: .leading) {
                Text(exercise.name)
                    .font(.headline)
                HStack {
                    if let prescription {
                        Label(prescription, systemImage: (isTimed ? SetMeasure.Kind.time : .reps).symbol)
                            .monospacedDigit()
                    } else {
                        Label(SetMeasure.Kind.untracked.label, systemImage: SetMeasure.Kind.untracked.symbol)
                    }
                    if showsDefaultHint {
                        Text("default")
                            .foregroundStyle(.tertiary)
                    }
                    if let progressText {
                        Label(progressText, systemImage: isComplete ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                            .foregroundStyle(isComplete ? .green : .accent)
                    }
                    if exercise.videoURL != nil {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
            Text("Exercise removed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG

#Preview("Variants") {
    List {
        Section("Library defaults") {
            ForEach(PreviewData.exercises) { exercise in
                ExerciseRow(library: exercise)
            }
        }
        Section("Inside a workout — per-workout values") {
            ForEach(PreviewData.workout.sortedExercises) { slot in
                ExerciseRow(slot: slot)
            }
        }
        Section("Timed, with recorded progress") {
            ForEach(PreviewData.timedWorkout.sortedExercises) { slot in
                ExerciseRow(slot: slot)
            }
        }
        Section("Exercise deleted from the library") {
            ExerciseRow(exercise: nil)
        }
    }
    .modelContainer(PreviewData.container)
}

#endif

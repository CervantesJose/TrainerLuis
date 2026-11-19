import Foundation
import SwiftData

/// A reusable movement in the exercise library.
///
/// `sets` and the measure here are only the *starting* values copied in when the exercise is
/// added to a workout. The values actually performed on a given day live on
/// ``WorkoutExercise``, so editing Monday's workout never rewrites the library or Thursday's.
///
/// The three measure fields are stored as plain optionals so they stay queryable in
/// `#Predicate` and migrate lightly, but they are only ever read and written through
/// ``measure``, which keeps at most one of them populated.
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""

    /// How many sets. `nil` means the exercise isn't set-based at all — a single continuous
    /// effort, or a warm-up that's simply done.
    var sets: Int? = SetMeasure.defaultSets

    /// Backing storage for ``measure``. Mutually exclusive with ``durationSeconds``.
    var reps: Int? = SetMeasure.defaultReps

    /// Backing storage for ``measure``. Mutually exclusive with ``reps``.
    var durationSeconds: Int?

    var videoURL: String?
    var notes: String?
    var createdAt: Date = Date()

    /// Every workout slot referencing this exercise. Cascading means removing an exercise
    /// from the library also removes it from the workouts that used it, instead of leaving
    /// behind rows whose `exercise` is nil and which silently disappear from the UI.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.exercise)
    var usages: [WorkoutExercise] = []

    init(
        name: String,
        sets: Int? = SetMeasure.defaultSets,
        measure: SetMeasure = .reps(SetMeasure.defaultReps),
        videoURL: String? = nil,
        notes: String? = nil
    ) {
        let measure = measure.normalized
        self.id = UUID()
        self.name = name
        self.sets = sets.map { max(1, $0) }
        self.reps = measure.repCount
        self.durationSeconds = measure.seconds
        self.videoURL = videoURL
        self.notes = notes
        self.createdAt = Date()
    }

    /// What one set of this movement is counted in. Writing it clears whichever backing
    /// field no longer applies, so `reps` and `durationSeconds` can never both be set.
    var measure: SetMeasure {
        get {
            if let durationSeconds { return .time(seconds: durationSeconds) }
            if let reps { return .reps(reps) }
            return .untracked
        }
        set {
            let normalized = newValue.normalized
            reps = normalized.repCount
            durationSeconds = normalized.seconds
        }
    }

    /// e.g. "4 × 8", "3 × 0:15", "15:00". nil when there's nothing to print.
    var prescription: String? { SetPrescription.text(sets: sets, measure: measure) }

    var isTimed: Bool { measure.isTimed }

    /// Number of distinct workouts this exercise currently appears in.
    var workoutUsageCount: Int {
        Set(usages.compactMap { $0.workout?.persistentModelID }).count
    }
}

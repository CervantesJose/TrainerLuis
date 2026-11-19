import Foundation
import SwiftData

/// One exercise slot inside a specific workout.
///
/// `sets` and the measure are per-workout: they are seeded from ``Exercise`` when the slot is
/// created but are independent afterwards, so the same movement can be 4×8 on Monday and
/// 3×12 on Thursday — or 15-second sprints one day and 30-second sprints the next.
@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    var order: Int = 0

    /// How many sets. `nil` means a single continuous effort or an untracked warm-up.
    var sets: Int? = SetMeasure.defaultSets

    /// Backing storage for ``measure``. Mutually exclusive with ``durationSeconds``.
    var reps: Int? = SetMeasure.defaultReps

    /// Backing storage for ``measure``. Mutually exclusive with ``reps``.
    var durationSeconds: Int?

    /// How many sets have actually been performed. Persisted because it belongs to this
    /// day's slot — Monday's progress isn't Thursday's — and it survives leaving the screen
    /// mid-workout. Advanced by the set timer.
    var completedSets: Int = 0

    /// Slots sharing a `supersetID` are performed back-to-back as one superset.
    /// `nil` means the exercise stands alone. Slots in the same group are always kept
    /// contiguous in `order` so the group reads as a single block.
    var supersetID: UUID?

    var exercise: Exercise?
    var workout: Workout?

    init(
        exercise: Exercise,
        order: Int,
        sets: Int?,
        measure: SetMeasure,
        supersetID: UUID? = nil
    ) {
        let measure = measure.normalized
        self.id = UUID()
        self.exercise = exercise
        self.order = order
        self.sets = sets.map { max(1, $0) }
        self.reps = measure.repCount
        self.durationSeconds = measure.seconds
        self.completedSets = 0
        self.supersetID = supersetID
    }

    /// Creates a slot using the library exercise's defaults.
    convenience init(exercise: Exercise, order: Int) {
        self.init(
            exercise: exercise,
            order: order,
            sets: exercise.sets,
            measure: exercise.measure
        )
    }

    /// What one set of this slot is counted in. Writing it clears whichever backing field no
    /// longer applies, so `reps` and `durationSeconds` can never both be set.
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

    var isInSuperset: Bool { supersetID != nil }

    /// e.g. "4 × 8", "3 × 0:15", "15:00". nil when there's nothing to print.
    var prescription: String? { SetPrescription.text(sets: sets, measure: measure) }

    var isTimed: Bool { measure.isTimed }

    /// Seconds each set runs for, when this slot is timed.
    var setSeconds: Int? { measure.seconds }

    // MARK: Progress

    /// Sets to perform. An exercise with no set count still has one round to do, so an
    /// untracked warm-up can be ticked off like anything else.
    var totalSets: Int { max(1, sets ?? 1) }

    /// Clamped, because editing a workout down from 5 sets to 3 shouldn't leave a slot
    /// claiming more sets done than it has.
    var setsDone: Int { min(max(0, completedSets), totalSets) }

    var isComplete: Bool { setsDone >= totalSets }

    /// 1-based number of the set to perform next, or nil once they're all done.
    var nextSet: Int? { isComplete ? nil : setsDone + 1 }

    /// e.g. "Set 2 of 3", or "Done" — nil while nothing has been performed yet, so an
    /// untouched row stays uncluttered.
    var progressText: String? {
        guard setsDone > 0 else { return nil }
        if isComplete { return totalSets > 1 ? "\(totalSets) sets done" : "Done" }
        return "\(setsDone) of \(totalSets) done"
    }

    /// Records one performed set. Idempotent at the top: finishing the last set again is a
    /// no-op rather than pushing the count past the total.
    func recordSetDone() {
        completedSets = min(totalSets, setsDone + 1)
    }

    func resetProgress() {
        completedSets = 0
    }
}

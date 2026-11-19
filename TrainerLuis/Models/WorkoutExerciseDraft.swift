import Foundation

/// A staged exercise slot, held in memory until the workout is saved.
///
/// Drafts let the *create* flow build a full workout — exercises, sets, measures, supersets —
/// before anything is inserted, so cancelling leaves nothing behind.
struct WorkoutExerciseDraft: Identifiable {
    let id: UUID
    /// The stored slot this draft came from; nil for a newly added exercise.
    var existing: WorkoutExercise?
    var exercise: Exercise

    /// nil means "use the library default", which the field shows as its placeholder.
    var sets: Int?

    /// Which measure the row is editing. Held separately from the values so switching to
    /// Time and back doesn't discard what was typed in the Reps field, and so a blank field
    /// still means "use the default" rather than "untracked".
    var kind: SetMeasure.Kind

    var reps: Int?
    var durationSeconds: Int?

    /// What a blank Sets field will actually save as, and therefore what its placeholder
    /// must show. Falling back to the library exercise first is what keeps a 15 minute jog
    /// from quietly becoming three of them when the workout is edited and re-saved.
    var setsPlaceholder: Int {
        exercise.sets ?? kind.defaultSets ?? 1
    }

    /// An untracked exercise has nothing to repeat, so it carries no set count.
    var resolvedSets: Int? {
        guard kind != .untracked else { return nil }
        return max(1, sets ?? setsPlaceholder)
    }

    /// Falls back to the library exercise's own value for the chosen measure, then to the
    /// app-wide default if the library exercise doesn't use that measure either.
    var resolvedMeasure: SetMeasure {
        switch kind {
        case .reps:
            .reps(reps ?? exercise.measure.repCount ?? SetMeasure.defaultReps)
        case .time:
            .time(seconds: durationSeconds ?? exercise.measure.seconds ?? SetMeasure.defaultSeconds)
        case .untracked:
            .untracked
        }
    }

    /// e.g. "3 × 0:15" — what the row will save as, defaults filled in.
    var resolvedPrescription: String? {
        SetPrescription.text(sets: resolvedSets, measure: resolvedMeasure)
    }

    var supersetID: UUID?

    init(exercise: Exercise, supersetID: UUID? = nil) {
        self.id = UUID()
        self.existing = nil
        self.exercise = exercise
        // Seeded from the library so adding a timed exercise lands on the Time field.
        self.kind = exercise.measure.kind
        self.supersetID = supersetID
    }

    init(slot: WorkoutExercise, exercise: Exercise) {
        self.id = slot.id
        self.existing = slot
        self.exercise = exercise
        self.sets = slot.sets
        self.kind = slot.measure.kind
        self.reps = slot.measure.repCount
        self.durationSeconds = slot.measure.seconds
        self.supersetID = slot.supersetID
    }
}

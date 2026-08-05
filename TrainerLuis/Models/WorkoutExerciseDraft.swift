import Foundation

/// A staged exercise slot, held in memory until the workout is saved.
///
/// Drafts let the *create* flow build a full workout — exercises, sets/reps, supersets —
/// before anything is inserted, so cancelling leaves nothing behind.
struct WorkoutExerciseDraft: Identifiable {
    let id: UUID
    /// The stored slot this draft came from; nil for a newly added exercise.
    var existing: WorkoutExercise?
    var exercise: Exercise
    /// nil means "use the library default", which the field shows as its placeholder.
    var sets: Int?
    var reps: Int?
    var supersetID: UUID?

    var resolvedSets: Int { sets ?? exercise.sets }
    var resolvedReps: Int { reps ?? exercise.reps }

    init(exercise: Exercise, supersetID: UUID? = nil) {
        self.id = UUID()
        self.existing = nil
        self.exercise = exercise
        self.supersetID = supersetID
    }

    init(slot: WorkoutExercise, exercise: Exercise) {
        self.id = slot.id
        self.existing = slot
        self.exercise = exercise
        self.sets = slot.sets
        self.reps = slot.reps
        self.supersetID = slot.supersetID
    }
}

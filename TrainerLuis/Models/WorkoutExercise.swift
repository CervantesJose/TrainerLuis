import Foundation
import SwiftData

/// One exercise slot inside a specific workout.
///
/// `sets` and `reps` are per-workout: they are seeded from ``Exercise`` when the slot is
/// created but are independent afterwards, so the same movement can be 4×8 on Monday and
/// 3×12 on Thursday.
@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    var order: Int = 0
    var sets: Int = 3
    var reps: Int = 10

    /// Slots sharing a `supersetID` are performed back-to-back as one superset.
    /// `nil` means the exercise stands alone. Slots in the same group are always kept
    /// contiguous in `order` so the group reads as a single block.
    var supersetID: UUID?

    var exercise: Exercise?
    var workout: Workout?

    init(exercise: Exercise, order: Int, sets: Int, reps: Int, supersetID: UUID? = nil) {
        self.id = UUID()
        self.exercise = exercise
        self.order = order
        self.sets = max(1, sets)
        self.reps = max(1, reps)
        self.supersetID = supersetID
    }

    /// Creates a slot using the library exercise's defaults.
    convenience init(exercise: Exercise, order: Int) {
        self.init(exercise: exercise, order: order, sets: exercise.sets, reps: exercise.reps)
    }

    var isInSuperset: Bool { supersetID != nil }

    /// e.g. "4 × 8"
    var setsAndReps: String { "\(sets) × \(reps)" }
}

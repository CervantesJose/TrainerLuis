import Foundation
import SwiftData

/// A reusable movement in the exercise library.
///
/// `sets` and `reps` here are only the *starting* values copied in when the exercise is
/// added to a workout. The values actually performed on a given day live on
/// ``WorkoutExercise``, so editing Monday's workout never rewrites the library or Thursday's.
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var sets: Int = 3
    var reps: Int = 10
    var videoURL: String?
    var notes: String?
    var createdAt: Date = Date()

    /// Every workout slot referencing this exercise. Cascading means removing an exercise
    /// from the library also removes it from the workouts that used it, instead of leaving
    /// behind rows whose `exercise` is nil and which silently disappear from the UI.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.exercise)
    var usages: [WorkoutExercise] = []

    init(name: String, sets: Int = 3, reps: Int = 10, videoURL: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.videoURL = videoURL
        self.notes = notes
        self.createdAt = Date()
    }

    /// Number of distinct workouts this exercise currently appears in.
    var workoutUsageCount: Int {
        Set(usages.compactMap { $0.workout?.persistentModelID }).count
    }
}

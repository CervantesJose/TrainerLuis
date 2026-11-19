#if DEBUG
import Foundation
import SwiftData

/// Shared sample data for SwiftUI previews.
///
/// Any view driven by `@Query` needs a `ModelContainer` in the environment or the preview
/// fails outright — and an *empty* container only ever renders the empty state, so a preview
/// meant to showcase a populated screen has to be seeded.
///
/// Debug-only: this never ships in a Release build.
@MainActor
enum PreviewData {
    /// In-memory container seeded with an exercise library and two workouts.
    static let container: ModelContainer = makeContainer(seeded: true)

    /// In-memory container with no records, for previewing empty states.
    static let emptyContainer: ModelContainer = makeContainer(seeded: false)

    static var exercises: [Exercise] {
        fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
    }

    static var workouts: [Workout] {
        fetch(FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt)]
        ))
    }

    /// The workout containing a superset — matched on that rather than on "most recent",
    /// because today holds more than one workout in the seed.
    ///
    /// Non-optional so previews read cleanly. The force-unwrap is safe because `seed` always
    /// inserts it, and an empty result would mean preview setup is broken anyway.
    static var workout: Workout {
        workouts.first { $0.supersetCount > 0 } ?? workouts.first!
    }

    /// The group id of `workout`'s superset, for previewing the combined superset screen.
    static var supersetID: UUID? {
        workout.blocks.first { $0.isSuperset }?.id
    }

    /// An exercise that has a demo video attached.
    static var exercise: Exercise {
        exercises.first { $0.videoURL != nil } ?? exercises[0]
    }

    /// A timed exercise, for previewing the Time measure and the duration fields.
    static var timedExercise: Exercise {
        exercises.first { $0.isTimed } ?? exercises[0]
    }

    /// The workout mixing timed sets, a single continuous effort and an untracked warm-up.
    static var timedWorkout: Workout {
        workouts.first { $0.workoutExercises.contains(where: \.isTimed) } ?? workouts[0]
    }

    /// A slot with several timed sets, one of them already recorded.
    static var timedSlot: WorkoutExercise {
        timedWorkout.sortedExercises.first { $0.isTimed && $0.totalSets > 1 }
            ?? timedWorkout.sortedExercises[0]
    }

    /// A single continuous timed effort — the 15 minute jog.
    static var runSlot: WorkoutExercise {
        timedWorkout.sortedExercises.first { $0.isTimed && $0.totalSets == 1 }
            ?? timedWorkout.sortedExercises[0]
    }

    /// Ids of the exercises already in `workout`, i.e. what a picker opened from that workout
    /// would pass as `stagedIDs`.
    static var stagedIDs: Set<UUID> {
        Set(workout.workoutExercises.compactMap { $0.exercise?.id })
    }

    private static func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? container.mainContext.fetch(descriptor)) ?? []
    }

    private static func makeContainer(seeded: Bool) -> ModelContainer {
        let schema = Schema([Workout.self, Exercise.self, WorkoutExercise.self])
        // Force-try is deliberate: a failure here is a mistake in preview setup, and a
        // preview has no meaningful way to carry on without a container.
        let container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        if seeded { seed(into: container.mainContext) }
        return container
    }

    private static func seed(into context: ModelContext) {
        // Covers all three measures, so a preview of any row, editor or timer has something
        // representative to render rather than only rep-based lifts.
        let library = [
            Exercise(
                name: "Barbell Bench Press",
                sets: 4,
                measure: .reps(8),
                videoURL: "https://www.youtube.com/watch?v=nKVZBKoB6P4"
            ),
            Exercise(name: "Bent-Over Row", sets: 4, measure: .reps(10)),
            Exercise(name: "Cable Fly", sets: 3, measure: .reps(15)),
            Exercise(
                name: "Easy Run",
                sets: nil,
                measure: .time(seconds: 15 * 60),
                notes: "Conversational pace."
            ),
            Exercise(name: "Face Pull", sets: 3, measure: .reps(20)),
            Exercise(name: "Hill Sprint", sets: 6, measure: .time(seconds: 20)),
            Exercise(name: "Incline Curl", sets: 3, measure: .reps(12)),
            Exercise(name: "Overhead Press", sets: 3, measure: .reps(8), notes: "Keep the ribs down."),
            Exercise(name: "Plank", sets: 3, measure: .time(seconds: 45)),
            Exercise(
                name: "Roll Out Body",
                sets: nil,
                measure: .untracked,
                notes: "Foam roller, wherever's tight."
            ),
            Exercise(name: "Romanian Deadlift", sets: 4, measure: .reps(8)),
        ]
        for exercise in library { context.insert(exercise) }

        // Looked up by name so reordering or extending the library above can't silently
        // repoint a seeded workout at the wrong movement.
        func exercise(_ name: String) -> Exercise {
            library.first { $0.name == name }!
        }

        let today = Calendar.current.startOfDay(for: Date())

        // Inserted first so it sorts ahead of the day's lifting session, giving previews a
        // day holding two workouts — the morning-run-plus-evening-lift case. Its slots are
        // the three shapes the measure axis exists for: a warm-up with nothing to count,
        // repeated timed sets, and one continuous timed effort.
        let run = Workout(name: "Morning Run", date: today)
        context.insert(run)

        // Only the timed slot carries progress, because the set timer is currently the only
        // thing that records any — seeding an untracked slot as done would preview a state
        // the app can't actually reach.
        let runPlan: [(exercise: Exercise, sets: Int?, measure: SetMeasure, done: Int)] = [
            (exercise("Roll Out Body"), nil, .untracked, 0),
            (exercise("Hill Sprint"), 3, .time(seconds: 15), 1),
            (exercise("Easy Run"), nil, .time(seconds: 15 * 60), 0),
        ]
        for (order, item) in runPlan.enumerated() {
            let slot = WorkoutExercise(
                exercise: item.exercise,
                order: order,
                sets: item.sets,
                measure: item.measure
            )
            slot.completedSets = item.done
            context.insert(slot)
            slot.workout = run
        }

        // The first two share a superset id so previews exercise the grouped rendering,
        // and their sets/measures deliberately differ from the library defaults.
        let supersetID = UUID()
        let push = Workout(name: "Evening Push / Pull A", date: today)
        context.insert(push)

        let plan: [(exercise: Exercise, sets: Int?, measure: SetMeasure, superset: UUID?)] = [
            (exercise("Barbell Bench Press"), 5, .reps(5), supersetID),
            (exercise("Bent-Over Row"), 5, .reps(12), supersetID),
            (exercise("Overhead Press"), 3, .reps(8), nil),
            (exercise("Plank"), 3, .time(seconds: 45), nil),
        ]
        for (order, item) in plan.enumerated() {
            let slot = WorkoutExercise(
                exercise: item.exercise,
                order: order,
                sets: item.sets,
                measure: item.measure,
                supersetID: item.superset
            )
            context.insert(slot)
            slot.workout = push
        }

        // A completed workout on an earlier day, so list/duplicate previews have something
        // to copy from and the calendar shows both dot colours.
        let earlier = Calendar.current.date(byAdding: .day, value: -3, to: today) ?? today
        let legs = Workout(name: "Legs A", date: earlier)
        legs.isCompleted = true
        context.insert(legs)

        let legSlot = WorkoutExercise(
            exercise: exercise("Romanian Deadlift"),
            order: 0,
            sets: 4,
            measure: .reps(8)
        )
        context.insert(legSlot)
        legSlot.workout = legs

        // Commit so the accessors above read committed rows instead of depending on
        // pending-change visibility in a fetch.
        try? context.save()
    }
}
#endif

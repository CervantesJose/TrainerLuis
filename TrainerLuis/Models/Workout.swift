import Foundation
import SwiftData

/// A training session on a specific calendar day.
///
/// A day can hold any number of workouts — a morning run and an evening lifting session are
/// two separate `Workout`s sharing one date, ordered within the day by ``createdAt``. To build
/// a session quickly, duplicate an existing one with ``duplicate(to:named:in:)``.
@Model
final class Workout {
    var id: UUID = UUID()
    var name: String = ""

    /// Always normalized to the start of the day, so grouping workouts by day never
    /// depends on the time component.
    var date: Date = Date()

    var isCompleted: Bool = false
    var notes: String?
    var createdAt: Date = Date()

    /// The inverse is declared explicitly: without it SwiftData can treat
    /// `Workout.workoutExercises` and `WorkoutExercise.workout` as two unrelated
    /// relationships, which makes appended exercises fail to survive a relaunch.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var workoutExercises: [WorkoutExercise] = []

    init(name: String, date: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.date = Calendar.current.startOfDay(for: date)
        self.isCompleted = false
        self.createdAt = Date()
    }

    var sortedExercises: [WorkoutExercise] {
        workoutExercises.sorted { $0.order < $1.order }
    }

    var exerciseCount: Int { workoutExercises.count }

    /// The exercises grouped into blocks, where each block is either a lone exercise or a
    /// superset performed back-to-back.
    var blocks: [WorkoutBlock] {
        var result: [WorkoutBlock] = []
        for slot in sortedExercises {
            guard let groupID = slot.supersetID else {
                result.append(.single(slot))
                continue
            }
            if case .superset(let lastID, var members)? = result.last, lastID == groupID {
                members.append(slot)
                result[result.count - 1] = .superset(id: lastID, exercises: members)
            } else {
                result.append(.superset(id: groupID, exercises: [slot]))
            }
        }
        // A group that ended up with a single member isn't a superset.
        return result.map { block in
            if case .superset(_, let members) = block, members.count == 1 {
                return .single(members[0])
            }
            return block
        }
    }

    var supersetCount: Int {
        blocks.filter { if case .superset = $0 { return true } else { return false } }.count
    }

    /// e.g. "5 exercises · 2 supersets"
    var summary: String {
        var parts = ["\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"]
        let supersets = supersetCount
        if supersets > 0 {
            parts.append("\(supersets) superset\(supersets == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Superset grouping

/// A displayable unit of a workout: one exercise, or several performed as a superset.
enum WorkoutBlock: Identifiable {
    case single(WorkoutExercise)
    case superset(id: UUID, exercises: [WorkoutExercise])

    var id: UUID {
        switch self {
        case .single(let slot): slot.id
        case .superset(let id, _): id
        }
    }

    var exercises: [WorkoutExercise] {
        switch self {
        case .single(let slot): [slot]
        case .superset(_, let members): members
        }
    }

    var isSuperset: Bool {
        if case .superset = self { return true }
        return false
    }
}

// MARK: - Workouts on a day

extension Workout {
    /// Every workout on `date`'s calendar day, in the order they were added.
    /// - Parameter excluded: a workout to leave out, so an editor doesn't list the workout
    ///   it is currently editing alongside the day's others.
    static func workouts(
        on date: Date,
        in context: ModelContext,
        excluding excluded: Workout? = nil
    ) -> [Workout] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        let matches = (try? context.fetch(descriptor)) ?? []
        return matches.filter { $0.persistentModelID != excluded?.persistentModelID }
    }
}

// MARK: - Duplication

extension Workout {
    /// Copies this workout — name, notes, exercises, per-workout sets/reps and superset
    /// grouping — onto another day. Any workout can therefore act as a template.
    ///
    /// Completion state is deliberately not copied: the copy hasn't been performed yet.
    @discardableResult
    func duplicate(to newDate: Date, named newName: String? = nil, in context: ModelContext) -> Workout {
        let copy = Workout(name: newName ?? name, date: newDate)
        copy.notes = notes
        context.insert(copy)

        // Supersets get fresh IDs so the copy's groups are independent of the original's.
        var remappedGroups: [UUID: UUID] = [:]

        for (index, slot) in sortedExercises.enumerated() {
            guard let exercise = slot.exercise else { continue }

            var newGroupID: UUID?
            if let oldGroupID = slot.supersetID {
                if let existing = remappedGroups[oldGroupID] {
                    newGroupID = existing
                } else {
                    let fresh = UUID()
                    remappedGroups[oldGroupID] = fresh
                    newGroupID = fresh
                }
            }

            let clone = WorkoutExercise(
                exercise: exercise,
                order: index,
                sets: slot.sets,
                reps: slot.reps,
                supersetID: newGroupID
            )
            context.insert(clone)
            clone.workout = copy
        }

        return copy
    }
}

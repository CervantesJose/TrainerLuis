import Foundation
import SwiftData

/// The current model set, stamped with a version.
///
/// Version 2 is where ``SetMeasure`` arrived: `sets` and `reps` became optional and
/// `durationSeconds` and `completedSets` joined them. Version 1 — non-optional `sets`/`reps`,
/// nothing else — is deliberately *not* snapshotted here. It was never shipped, so there is no
/// V1 store in the world to migrate from, and carrying a duplicate set of `@Model` classes
/// purely to describe it would be dead code that still has to be kept in step.
///
/// What this does buy is the next change: from here on, a store carries a version identifier,
/// so a V2 → V3 stage can be written as an actual migration rather than a guess about what's
/// on disk. Until then, a development store predating the stamp falls into the
/// recreate-from-scratch path in ``TrainerLuisApp``.
enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Workout.self, Exercise.self, WorkoutExercise.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV2.self] }

    /// Empty while there is only one version. Adding V3 means adding a stage here, not
    /// rediscovering that migrations exist.
    static var stages: [MigrationStage] { [] }
}

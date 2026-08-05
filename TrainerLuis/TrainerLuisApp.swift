import SwiftUI
import SwiftData
import OSLog

let appLog = Logger(subsystem: "com.trainerluis.app", category: "persistence")

@main
struct TrainerLuisApp: App {
    private let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    static let schema = Schema([Workout.self, Exercise.self, WorkoutExercise.self])

    /// Builds the on-disk container explicitly rather than via `.modelContainer(for:)`.
    ///
    /// Two reasons: the store URL is known, so an incompatible store left over from an older
    /// schema can be cleared instead of trapping on launch; and if disk storage is
    /// unavailable for any reason we fall back to memory *loudly* rather than looking like
    /// saves are silently being dropped.
    private static func makeContainer() -> ModelContainer {
        let supportDirectory = URL.applicationSupportDirectory
        let storeURL = supportDirectory.appending(path: "default.store")

        // Application Support isn't guaranteed to exist in a fresh app container.
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: storeURL)
            )
        } catch {
            appLog.error("Store at \(storeURL.path) could not be opened: \(error.localizedDescription). Recreating it.")
        }

        // The existing store predates the current schema and can't be migrated
        // automatically. Remove it (plus its write-ahead log) and start clean.
        for suffix in ["", "-shm", "-wal"] {
            let sidecar = URL(fileURLWithPath: storeURL.path + suffix)
            try? FileManager.default.removeItem(at: sidecar)
        }

        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: storeURL)
            )
        } catch {
            appLog.critical("Falling back to an in-memory store; changes will not persist: \(error.localizedDescription)")
            return try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
    }
}

extension ModelContext {
    /// Saves and reports failures instead of discarding them with `try?`.
    ///
    /// SwiftData also autosaves, but committing at the end of an explicit user action keeps
    /// what's on screen and what's on disk in step — and surfaces validation errors that
    /// would otherwise look like "my workout didn't save".
    func saveChanges(during operation: String = #function) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            appLog.error("Save failed during \(operation, privacy: .public): \(error.localizedDescription)")
        }
    }
}

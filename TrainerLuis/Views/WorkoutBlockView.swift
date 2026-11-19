import SwiftUI

// MARK: - Block rendering

/// Renders one unit of a workout: a lone exercise, or a superset drawn as a labelled group
/// so it reads as "do these back-to-back" rather than as separate exercises.
///
/// Timed slots get a different primary tap: running the countdown is the thing you want one
/// tap away mid-workout, so those rows open the timer and keep the library details on a
/// long press. Untimed rows push the details as before.
///
/// A superset's members deliberately don't each carry their own `NavigationLink`: several
/// links in one list row all fire together, which pushed a detail screen per member. The
/// group opens as a single ``SupersetDetailView`` instead.
struct WorkoutBlockView: View {
    let block: WorkoutBlock

    /// Whether a lone exercise pushes an ``ExerciseDetailView``. Off in read-only previews.
    var showsNavigation: Bool = false

    /// Set to make timed rows open a countdown. Left nil in previews, where the rows are
    /// inert and there's nowhere to present a sheet.
    var onStartTimer: ((WorkoutExercise) -> Void)?

    /// How a timed row reaches the exercise's library details, since its tap is spoken for.
    var onShowDetails: ((Exercise) -> Void)?

    /// Opens the whole superset on one screen, by group id. Left nil where the rows are
    /// inert, which also drops the group's disclosure chevron.
    var onOpenSuperset: ((UUID) -> Void)?

    var body: some View {
        switch block {
        case .single(let slot):
            slotRow(slot, label: nil, superset: nil)

        case .superset(let groupID, let members):
            VStack(alignment: .leading, spacing: 8) {
                supersetHeader(groupID: groupID, count: members.count)

                ForEach(Array(members.enumerated()), id: \.element.id) { index, slot in
                    slotRow(slot, label: "\(index + 1)", superset: groupID)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.accentColor.opacity(0.07))
        }
    }

    @ViewBuilder
    private func supersetHeader(groupID: UUID, count: Int) -> some View {
        let content = HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.caption2)
            Text("Superset")
                .font(.caption.weight(.semibold))
            Text("· \(count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if onOpenSuperset != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.accent)

        if let onOpenSuperset {
            Button { onOpenSuperset(groupID) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    /// - Parameter superset: the group this row belongs to, or nil for a lone exercise. A
    ///   member's tap opens the group rather than the exercise, so the whole block leads to
    ///   the one screen.
    @ViewBuilder
    private func slotRow(_ slot: WorkoutExercise, label: String?, superset: UUID?) -> some View {
        if slot.isTimed, let onStartTimer {
            Button {
                onStartTimer(slot)
            } label: {
                HStack(spacing: 8) {
                    slotContent(slot, label: label)
                    Spacer(minLength: 8)
                    Image(systemName: slot.isComplete ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(slot.isComplete ? .green : .accent)
                }
            }
            .foregroundStyle(.primary)
            .contextMenu {
                if let superset, let onOpenSuperset {
                    Button {
                        onOpenSuperset(superset)
                    } label: {
                        Label("Superset Details", systemImage: "link")
                    }
                }
                if let exercise = slot.exercise, let onShowDetails {
                    Button {
                        onShowDetails(exercise)
                    } label: {
                        Label("Exercise Details", systemImage: "info.circle")
                    }
                }
            }
        } else if let superset, let onOpenSuperset {
            Button {
                onOpenSuperset(superset)
            } label: {
                HStack(spacing: 8) {
                    slotContent(slot, label: label)
                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)
        } else if superset == nil, showsNavigation, let exercise = slot.exercise {
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                slotContent(slot, label: label)
            }
        } else {
            slotContent(slot, label: label)
        }
    }

    private func slotContent(_ slot: WorkoutExercise, label: String?) -> some View {
        HStack(spacing: 8) {
            if let label {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .monospaced()
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.accentColor))
            }
            ExerciseRow(slot: slot)
        }
    }
}

#if DEBUG

/// The seeded workout is a superset of two followed by a lone exercise, so this covers both
/// block shapes in one canvas.
#Preview("Superset and single") {
    NavigationStack {
        List(PreviewData.workout.blocks) { block in
            WorkoutBlockView(
                block: block,
                showsNavigation: true,
                onOpenSuperset: { print("superset: \($0)") }
            )
        }
    }
    .modelContainer(PreviewData.container)
}

/// Timed and untracked slots, with the play affordance wired up.
#Preview("Timed and untracked") {
    NavigationStack {
        List(PreviewData.timedWorkout.blocks) { block in
            WorkoutBlockView(
                block: block,
                showsNavigation: true,
                onStartTimer: { print("timer: \($0.exercise?.name ?? "?")") }
            )
        }
    }
    .modelContainer(PreviewData.container)
}

#endif

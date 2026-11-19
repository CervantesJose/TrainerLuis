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
            row(for: slot, label: nil, superset: nil)

        case .superset(let groupID, let members):
            VStack(alignment: .leading) {
                SupersetHeader(
                    count: members.count,
                    onOpen: onOpenSuperset.map { open in { open(groupID) } }
                )

                ForEach(members.enumerated(), id: \.element.id) { index, slot in
                    row(for: slot, label: "\(index + 1)", superset: groupID)
                }
            }
            .listRowBackground(Color.accentColor.opacity(0.07))
        }
    }

    private func row(for slot: WorkoutExercise, label: String?, superset: UUID?) -> SlotRow {
        SlotRow(
            slot: slot,
            label: label,
            superset: superset,
            showsNavigation: showsNavigation,
            onStartTimer: onStartTimer,
            onShowDetails: onShowDetails,
            onOpenSuperset: onOpenSuperset
        )
    }
}

// MARK: - Subviews

private struct SupersetHeader: View {
    let count: Int

    /// Opens the superset's own screen. Nil where rows are inert, which also drops the chevron.
    let onOpen: (() -> Void)?

    var body: some View {
        if let onOpen {
            Button(action: onOpen) {
                SupersetHeaderLabel(count: count, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            SupersetHeaderLabel(count: count, showsChevron: false)
        }
    }
}

private struct SupersetHeaderLabel: View {
    let count: Int
    let showsChevron: Bool

    var body: some View {
        HStack {
            Image(systemName: "link")
                .font(.caption2)
            Text("Superset")
                .font(.caption.weight(.semibold))
            Text("· \(count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.accent)
    }
}

/// One exercise in a block, with the tap behavior its kind calls for.
private struct SlotRow: View {
    let slot: WorkoutExercise

    /// The member's 1-based position in its superset, or nil for a lone exercise.
    let label: String?

    /// The group this row belongs to, or nil for a lone exercise. A member's tap opens the
    /// group rather than the exercise, so the whole block leads to the one screen.
    let superset: UUID?
    let showsNavigation: Bool
    let onStartTimer: ((WorkoutExercise) -> Void)?
    let onShowDetails: ((Exercise) -> Void)?
    let onOpenSuperset: ((UUID) -> Void)?

    var body: some View {
        if slot.isTimed, let onStartTimer {
            Button {
                onStartTimer(slot)
            } label: {
                HStack {
                    SlotContent(slot: slot, label: label)
                    Spacer()
                    Image(systemName: slot.isComplete ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(slot.isComplete ? .green : .accent)
                }
            }
            .foregroundStyle(.primary)
            .contextMenu {
                if let superset, let onOpenSuperset {
                    Button("Superset Details", systemImage: "link") {
                        onOpenSuperset(superset)
                    }
                }
                if let exercise = slot.exercise, let onShowDetails {
                    Button("Exercise Details", systemImage: "info.circle") {
                        onShowDetails(exercise)
                    }
                }
            }
        } else if let superset, let onOpenSuperset {
            Button {
                onOpenSuperset(superset)
            } label: {
                HStack {
                    SlotContent(slot: slot, label: label)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        } else if superset == nil, showsNavigation, let exercise = slot.exercise {
            NavigationLink(value: exercise) {
                SlotContent(slot: slot, label: label)
            }
        } else {
            SlotContent(slot: slot, label: label)
        }
    }
}

private struct SlotContent: View {
    let slot: WorkoutExercise
    let label: String?

    var body: some View {
        HStack {
            if let label {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .monospaced()
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(.tint, in: .circle)
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

import SwiftUI

// MARK: - Block rendering

/// Renders one unit of a workout: a lone exercise, or a superset drawn as a labelled group
/// so it reads as "do these back-to-back" rather than as separate exercises.
struct WorkoutBlockView: View {
    let block: WorkoutBlock
    /// Whether rows push an ``ExerciseDetailView``. Off in read-only previews.
    var showsNavigation: Bool = false

    var body: some View {
        switch block {
        case .single(let slot):
            slotRow(slot, label: nil)

        case .superset(_, let members):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text("Superset")
                        .font(.caption.weight(.semibold))
                    Text("· \(members.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.accent)

                ForEach(Array(members.enumerated()), id: \.element.id) { index, slot in
                    slotRow(slot, label: "\(index + 1)")
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.accentColor.opacity(0.07))
        }
    }

    @ViewBuilder
    private func slotRow(_ slot: WorkoutExercise, label: String?) -> some View {
        if showsNavigation, let exercise = slot.exercise {
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                slotContent(slot, label: label)
            }
        } else {
            slotContent(slot, label: label)
        }
    }

    @ViewBuilder
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
            ExerciseRow(
                exercise: slot.exercise,
                sets: slot.sets,
                reps: slot.reps
            )
        }
    }
}

#if DEBUG

/// The seeded workout is a superset of two followed by a lone exercise, so this covers both
/// block shapes in one canvas.
#Preview("Superset and single") {
    NavigationStack {
        List(PreviewData.workout.blocks) { block in
            WorkoutBlockView(block: block, showsNavigation: true)
        }
    }
    .modelContainer(PreviewData.container)
}

#endif

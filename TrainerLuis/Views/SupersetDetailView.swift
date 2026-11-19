import SwiftUI
import SwiftData

/// A whole superset on one screen.
///
/// Its members used to be separate `NavigationLink`s sharing a single list row, so one tap
/// pushed a detail view per member — a two-exercise superset landed two screens deep, in
/// reverse order. A superset is performed as one unit, so it reads as one screen: every
/// member's prescription, progress, demo video and notes, in the order they're performed.
///
/// Structural editing — sets, measures, grouping, order — stays in ``CreateWorkoutView``,
/// reachable from the toolbar, so there's still only one place a workout's shape can change.
struct SupersetDetailView: View {
    @Bindable var workout: Workout
    let supersetID: UUID

    /// The member whose countdown is on screen.
    @State private var timerSlot: WorkoutExercise?

    @State private var showingEditWorkout = false

    /// Resolved from the workout on each render rather than passed in, so edits made in the
    /// sheet below — reordering, removing a member, ungrouping — land here immediately.
    private var members: [WorkoutExercise] {
        workout.sortedExercises.filter { $0.supersetID == supersetID }
    }

    var body: some View {
        List {
            let members = members
            if members.isEmpty {
                NoLongerSupersetSection()
            } else {
                SupersetOverviewSection(workoutName: workout.name, members: members)
                ForEach(members.enumerated(), id: \.element.id) { index, slot in
                    SupersetMemberSection(slot: slot, position: index + 1) {
                        timerSlot = slot
                    }
                }
            }
        }
        .navigationTitle("Superset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit Workout", systemImage: "pencil") {
                    showingEditWorkout = true
                }
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            CreateWorkoutView(workout: workout)
        }
        .sheet(item: $timerSlot) { slot in
            SetTimerView(slot: slot)
        }
    }
}

// MARK: - Subviews

/// Reachable by editing the group away while its screen is still on the stack, rather
/// than by tapping into it — hence a plain explanation instead of an error.
private struct NoLongerSupersetSection: View {
    var body: some View {
        Section {
            ContentUnavailableView(
                "No Longer a Superset",
                systemImage: "scissors",
                description: Text("These exercises aren't grouped any more. Go back to see the workout.")
            )
        }
    }
}

private struct SupersetOverviewSection: View {
    let workoutName: String
    let members: [WorkoutExercise]

    var body: some View {
        Section {
            Label(
                "\(members.count) exercises, back-to-back",
                systemImage: "link"
            )
            .font(.subheadline)

            if let line = prescriptionLine {
                LabeledContent("Prescription", value: line)
                    .monospacedDigit()
            }
        } header: {
            Text(workoutName)
                .textCase(nil)
        } footer: {
            Text("One set of each in order, then rest and repeat.")
        }
    }

    /// The group's prescriptions on one line — "5 × 5 · 5 × 12".
    private var prescriptionLine: String? {
        let parts = members.compactMap(\.prescription)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// One member's prescription, progress, demo video and notes.
private struct SupersetMemberSection: View {
    let slot: WorkoutExercise

    /// 1-based position in the superset.
    let position: Int
    let onStartTimer: () -> Void

    var body: some View {
        Section {
            if let sets = slot.sets {
                LabeledContent("Sets", value: "\(sets)")
            }
            switch slot.measure {
            case .reps(let count):
                LabeledContent("Reps", value: "\(count)")
            case .time(let seconds):
                LabeledContent("Time per set", value: SetMeasure.unitTimeText(seconds))
            case .untracked:
                LabeledContent("Target", value: "None")
            }

            if let progress = slot.progressText {
                LabeledContent("Progress") {
                    Label(progress, systemImage: slot.isComplete ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                        .foregroundStyle(slot.isComplete ? .green : .accent)
                }
            }

            if slot.isTimed {
                Button {
                    onStartTimer()
                } label: {
                    Label(
                        slot.isComplete ? "Run Timer Again" : "Start Set Timer",
                        systemImage: slot.isComplete ? "arrow.counterclockwise" : "play.circle.fill"
                    )
                }
            }

            if let url = slot.exercise?.videoURL, !url.isEmpty {
                VideoPlayerView(urlString: url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 10))
                    .listRowInsets(.init(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            if let notes = slot.exercise?.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // The one push left on this screen, and it's deliberate: library defaults and
            // usage belong to the exercise, not to this workout's slot.
            if let exercise = slot.exercise {
                NavigationLink(value: exercise) {
                    Label("Exercise Details", systemImage: "info.circle")
                }
            }
        } header: {
            HStack(spacing: 8) {
                Text("\(position)")
                    .font(.caption2.weight(.bold))
                    .monospaced()
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(.tint, in: .circle)
                Text(slot.exercise?.name ?? "Exercise removed")
                    .font(.headline)
            }
            .textCase(nil)
            .padding(.vertical, 2)
        }
    }
}

#if DEBUG

/// The seeded push workout opens on its bench/row superset.
#Preview("Two exercises") {
    NavigationStack {
        SupersetDetailView(
            workout: PreviewData.workout,
            supersetID: PreviewData.supersetID ?? UUID()
        )
    }
    .modelContainer(PreviewData.container)
}

/// What's left after the group is edited away while this screen is open.
#Preview("Ungrouped while open") {
    NavigationStack {
        SupersetDetailView(workout: PreviewData.workout, supersetID: UUID())
    }
    .modelContainer(PreviewData.container)
}

#endif

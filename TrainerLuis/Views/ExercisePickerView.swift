import SwiftData
import SwiftUI

/// Multi-select picker over the exercise library, with an option to add the selection as a
/// single superset and a shortcut to create a missing exercise inline.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    /// Exercises already staged in the workout — flagged, but not blocked: a workout may
    /// legitimately repeat a movement.
    var stagedIDs: Set<UUID> = []
    var onAdd: ([Exercise], Bool) -> Void

    @State private var searchText = ""
    /// Ordered, so exercises are added in the order they were tapped.
    @State private var selection: [UUID] = []
    @State private var addAsSuperset = false
    @State private var showingCreate = false

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    ContentUnavailableView {
                        Label("No Exercises Yet", systemImage: "figure.strengthtraining.traditional")
                    } description: {
                        Text("Create an exercise to add it to this workout.")
                    } actions: {
                        Button("New Exercise") { showingCreate = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if selection.count > 1 {
                            Section {
                                Toggle(isOn: $addAsSuperset) {
                                    Label("Add as one superset", systemImage: "link")
                                }
                            } footer: {
                                Text("The \(selection.count) selected exercises will be performed back-to-back.")
                            }
                        }

                        Section {
                            ForEach(filtered) { exercise in
                                PickerRow(
                                    exercise: exercise,
                                    isSelected: selection.contains(exercise.id),
                                    isStaged: stagedIDs.contains(exercise.id)
                                ) {
                                    toggle(exercise)
                                }
                            }

                            if !exercises.isEmpty {
                                Button("New Exercise", systemImage: "plus") {
                                    showingCreate = true
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search exercises")
                }
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selection.isEmpty ? "Add" : "Add \(selection.count)") { commit() }
                        .disabled(selection.isEmpty)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateExerciseView()
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        if let index = selection.firstIndex(of: exercise.id) {
            selection.remove(at: index)
        } else {
            selection.append(exercise.id)
        }
        if selection.count < 2 { addAsSuperset = false }
    }

    private func commit() {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        onAdd(selection.compactMap { byID[$0] }, addAsSuperset)
        dismiss()
    }
}

// MARK: - Subviews

private struct PickerRow: View {
    let exercise: Exercise
    let isSelected: Bool

    /// Already in the workout — flagged, but still selectable.
    let isStaged: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                ExerciseRow(
                    exercise: exercise,
                    prescription: exercise.prescription,
                    isTimed: exercise.isTimed
                )

                Spacer()

                if isStaged {
                    Text("In workout")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: .capsule)
                }
            }
        }
        .foregroundStyle(.primary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG

#Preview("Populated") {
    ExercisePickerView(stagedIDs: PreviewData.stagedIDs) { picked, asSuperset in
        print("added \(picked.map(\.name)) — superset: \(asSuperset)")
    }
    .modelContainer(PreviewData.container)
}

/// Tap two or more rows in the canvas to reveal the "Add as one superset" toggle — it's
/// driven by private state, so it can't be pre-selected from outside.
#Preview("Empty Library") {
    ExercisePickerView { _, _ in }
        .modelContainer(PreviewData.emptyContainer)
}

/// The picker is only ever shown as a sheet, so this is the faithful presentation context.
#Preview("Presented as a sheet") {
    ExercisePickerSheetPreview()
        .modelContainer(PreviewData.container)
}

private struct ExercisePickerSheetPreview: View {
    @State private var isPresented = true

    var body: some View {
        NavigationStack {
            Text("Workout editor")
                .foregroundStyle(.secondary)
                .navigationTitle("New Workout")
        }
        .sheet(isPresented: $isPresented) {
            ExercisePickerView(stagedIDs: PreviewData.stagedIDs) { _, _ in }
        }
    }
}

#endif

import SwiftUI
import SwiftData

struct CreateWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var workout: Workout? // nil = create, non-nil = edit
    var initialDate: Date = Date()

    @State private var name = ""
    @State private var date = Date()
    @State private var drafts: [WorkoutExerciseDraft] = []

    /// The day's other workouts, shown so a second session on a day is a deliberate choice
    /// rather than a surprise. Cached rather than computed in `body` so each render doesn't
    /// hit the store.
    @State private var sameDay: [Workout] = []

    @State private var showingExercisePicker = false
    @State private var showingSourcePicker = false
    @State private var hasLoaded = false

    var isEditing: Bool { workout != nil }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                infoSection
                exercisesSection
                if !isEditing && drafts.isEmpty {
                    startFromSection
                }
            }
            .navigationTitle(isEditing ? "Edit Workout" : "New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
                if drafts.count > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                NumberPadDoneButton()
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(stagedIDs: Set(drafts.map(\.exercise.id))) { picked, asSuperset in
                    add(picked, asSuperset: asSuperset)
                }
            }
            .sheet(isPresented: $showingSourcePicker) {
                WorkoutSourcePickerView(excluding: workout) { source in
                    copyExercises(from: source)
                }
            }
            .onAppear(perform: load)
            .onChange(of: date) { _, _ in refreshSameDay() }
        }
    }

    // MARK: Sections

    private var infoSection: some View {
        Section {
            TextField("Workout Name", text: $name)
                .autocorrectionDisabled()

            DatePicker("Date", selection: $date, displayedComponents: .date)
        } header: {
            Text("Workout Info")
        } footer: {
            if sameDay.isEmpty {
                Text("A day can hold more than one workout — a morning run and an evening lift are two separate workouts.")
            } else {
                Text("Already on \(date.formatted(.dateTime.month().day())): \(sameDay.map(\.name).formatted(.list(type: .and))). This one will be added alongside \(sameDay.count == 1 ? "it" : "them").")
            }
        }
    }

    private var exercisesSection: some View {
        Section {
            ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                draftRow(draft, at: index)
            }
            .onDelete(perform: deleteDrafts)
            .onMove(perform: moveDrafts)

            Button {
                showingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
            }
        } header: {
            HStack {
                Text("Exercises")
                Spacer()
                if !drafts.isEmpty {
                    Text(drafts.count == 1 ? "1 exercise" : "\(drafts.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            if drafts.isEmpty {
                Text("Add the movements for this workout. Sets and targets here apply to this workout only — the library keeps its own defaults.")
            } else {
                Text("Swipe a row right to superset it with the one above. Tap a row's measure button to switch it between reps, a timed set, and nothing to count.")
            }
        }
    }

    private var startFromSection: some View {
        Section {
            Button {
                showingSourcePicker = true
            } label: {
                Label("Copy from an existing workout", systemImage: "doc.on.doc")
            }
        } footer: {
            Text("Reuses that workout's exercises, sets, targets and supersets as a starting point.")
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func draftRow(_ draft: WorkoutExerciseDraft, at index: Int) -> some View {
        let label = supersetLabels[draft.id]

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let label {
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .monospaced()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor))
                }
                Text(draft.exercise.name)
                    .font(.headline)
                Spacer()
                if draft.exercise.videoURL != nil {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.accent)
                }
                // Sits on the name line rather than beside the fields: three number boxes
                // plus a picker on one line squeezed the fields until their labels wrapped.
                measureMenu(for: draft)
            }

            HStack(spacing: 12) {
                if draft.kind != .untracked {
                    NumberField(
                        title: "Sets",
                        value: numberBinding(draft.id, \.sets),
                        placeholder: "\(draft.setsPlaceholder)"
                    )
                }

                switch draft.kind {
                case .reps:
                    NumberField(
                        title: "Reps",
                        value: numberBinding(draft.id, \.reps),
                        placeholder: "\(draft.exercise.measure.repCount ?? SetMeasure.defaultReps)"
                    )
                case .time:
                    DurationField(
                        title: "",
                        seconds: numberBinding(draft.id, \.durationSeconds),
                        placeholder: draft.exercise.measure.seconds ?? SetMeasure.defaultSeconds
                    )
                case .untracked:
                    Text("Nothing to count")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let resolved = draft.resolvedPrescription {
                    Text(resolved)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.accentColor.opacity(label == nil ? 0 : 0.07))
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if canGroupWithPrevious(index) {
                Button {
                    groupWithPrevious(index)
                } label: {
                    Label("Superset", systemImage: "link")
                }
                .tint(.accentColor)
            }
            if draft.supersetID != nil {
                Button {
                    ungroup(draft.id)
                } label: {
                    Label("Ungroup", systemImage: "scissors")
                }
                .tint(.orange)
            }
        }
        .contextMenu {
            if canGroupWithPrevious(index) {
                Button {
                    groupWithPrevious(index)
                } label: {
                    Label("Superset with above", systemImage: "link")
                }
            }
            if draft.supersetID != nil {
                Button {
                    ungroup(draft.id)
                } label: {
                    Label("Remove from superset", systemImage: "scissors")
                }
            }
            Button(role: .destructive) {
                remove(draft.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    /// A menu rather than a segmented control: three segments per row would crowd out the
    /// number fields, and the measure is picked once and then left alone.
    private func measureMenu(for draft: WorkoutExerciseDraft) -> some View {
        Menu {
            Picker("Measured in", selection: kindBinding(draft.id)) {
                ForEach(SetMeasure.Kind.allCases) { kind in
                    Label(kind.label, systemImage: kind.symbol).tag(kind)
                }
            }
        } label: {
            Image(systemName: draft.kind.symbol)
                .font(.subheadline)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.quaternary))
        }
        .buttonStyle(.borderless)
    }

    /// Maps each draft in a real (2+ member) superset to a label like "A1", "A2", "B1".
    private var supersetLabels: [UUID: String] {
        var memberCounts: [UUID: Int] = [:]
        for draft in drafts {
            if let group = draft.supersetID { memberCounts[group, default: 0] += 1 }
        }

        var letters: [UUID: String] = [:]
        var positions: [UUID: Int] = [:]
        var labels: [UUID: String] = [:]

        for draft in drafts {
            guard let group = draft.supersetID, memberCounts[group, default: 0] > 1 else { continue }
            let letter = letters[group] ?? Self.groupLetter(letters.count)
            letters[group] = letter
            let position = positions[group, default: 0] + 1
            positions[group] = position
            labels[draft.id] = "\(letter)\(position)"
        }
        return labels
    }

    private static func groupLetter(_ index: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return index < alphabet.count ? String(alphabet[index]) : "\(index + 1)"
    }

    /// Looks the draft up by id on every access so reordering can't leave a stale index
    /// wired to the wrong field.
    private func numberBinding(
        _ draftID: UUID,
        _ keyPath: WritableKeyPath<WorkoutExerciseDraft, Int?>
    ) -> Binding<Int?> {
        Binding(
            get: { drafts.first { $0.id == draftID }?[keyPath: keyPath] ?? nil },
            set: { newValue in
                guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
                drafts[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func kindBinding(_ draftID: UUID) -> Binding<SetMeasure.Kind> {
        Binding(
            get: { drafts.first { $0.id == draftID }?.kind ?? .reps },
            set: { newValue in
                guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
                drafts[index].kind = newValue
            }
        )
    }

    // MARK: Draft mutations

    private func add(_ exercises: [Exercise], asSuperset: Bool) {
        let groupID = (asSuperset && exercises.count > 1) ? UUID() : nil
        drafts.append(contentsOf: exercises.map { WorkoutExerciseDraft(exercise: $0, supersetID: groupID) })
        normalizeGroups()
    }

    private func copyExercises(from source: Workout) {
        var remappedGroups: [UUID: UUID] = [:]
        var copied: [WorkoutExerciseDraft] = []

        for slot in source.sortedExercises {
            guard let exercise = slot.exercise else { continue }
            var groupID: UUID?
            if let old = slot.supersetID {
                if let existing = remappedGroups[old] {
                    groupID = existing
                } else {
                    let fresh = UUID()
                    remappedGroups[old] = fresh
                    groupID = fresh
                }
            }
            var draft = WorkoutExerciseDraft(exercise: exercise, supersetID: groupID)
            draft.sets = slot.sets
            draft.kind = slot.measure.kind
            draft.reps = slot.measure.repCount
            draft.durationSeconds = slot.measure.seconds
            copied.append(draft)
        }

        drafts.append(contentsOf: copied)
        if trimmedName.isEmpty { name = source.name }
        normalizeGroups()
    }

    private func deleteDrafts(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
        normalizeGroups()
    }

    private func remove(_ draftID: UUID) {
        drafts.removeAll { $0.id == draftID }
        normalizeGroups()
    }

    private func moveDrafts(from source: IndexSet, to destination: Int) {
        // Expand the selection so dragging one member drags its whole superset.
        var indices = Set(source)
        for index in source {
            guard let group = drafts[index].supersetID else { continue }
            for (other, draft) in drafts.enumerated() where draft.supersetID == group {
                indices.insert(other)
            }
        }
        drafts.move(fromOffsets: IndexSet(indices), toOffset: destination)
        normalizeGroups()
    }

    private func canGroupWithPrevious(_ index: Int) -> Bool {
        guard index > 0 else { return false }
        let previous = drafts[index - 1].supersetID
        return previous == nil || previous != drafts[index].supersetID
    }

    private func groupWithPrevious(_ index: Int) {
        guard index > 0 else { return }
        let groupID = drafts[index - 1].supersetID ?? UUID()
        drafts[index - 1].supersetID = groupID
        drafts[index].supersetID = groupID
        normalizeGroups()
    }

    private func ungroup(_ draftID: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].supersetID = nil
        normalizeGroups()
    }

    /// Keeps each superset's members contiguous and clears groups that are down to a single
    /// member, so what's on screen always matches how the workout will be stored.
    private func normalizeGroups() {
        var ordered: [WorkoutExerciseDraft] = []
        var placed: Set<UUID> = []

        for draft in drafts where !placed.contains(draft.id) {
            if let group = draft.supersetID {
                for member in drafts where member.supersetID == group && !placed.contains(member.id) {
                    placed.insert(member.id)
                    ordered.append(member)
                }
            } else {
                placed.insert(draft.id)
                ordered.append(draft)
            }
        }

        var memberCounts: [UUID: Int] = [:]
        for draft in ordered {
            if let group = draft.supersetID { memberCounts[group, default: 0] += 1 }
        }
        for index in ordered.indices {
            if let group = ordered[index].supersetID, memberCounts[group] == 1 {
                ordered[index].supersetID = nil
            }
        }

        drafts = ordered
    }

    // MARK: Load & save

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true

        if let workout {
            name = workout.name
            date = workout.date
            drafts = workout.sortedExercises.compactMap { slot in
                guard let exercise = slot.exercise else { return nil }
                return WorkoutExerciseDraft(slot: slot, exercise: exercise)
            }
            normalizeGroups()
        } else {
            date = Calendar.current.startOfDay(for: initialDate)
        }

        refreshSameDay()
    }

    private func refreshSameDay() {
        sameDay = Workout.workouts(on: date, in: modelContext, excluding: workout)
    }

    private func save() {
        guard canSave else { return }

        let day = Calendar.current.startOfDay(for: date)
        let target: Workout

        if let workout {
            target = workout
            target.name = trimmedName
            target.date = day
        } else {
            target = Workout(name: trimmedName, date: day)
            modelContext.insert(target)
        }

        // Reconcile the staged list against what's stored: delete dropped slots, then
        // update the survivors and insert the new ones in their final order.
        let keptIDs = Set(drafts.compactMap { $0.existing?.persistentModelID })
        for slot in target.workoutExercises where !keptIDs.contains(slot.persistentModelID) {
            modelContext.delete(slot)
        }

        for (index, draft) in drafts.enumerated() {
            if let slot = draft.existing {
                slot.order = index
                slot.sets = draft.resolvedSets
                slot.measure = draft.resolvedMeasure
                slot.supersetID = draft.supersetID
                // Editing 5 sets down to 3 shouldn't leave the slot claiming 5 performed.
                slot.completedSets = slot.setsDone
            } else {
                let slot = WorkoutExercise(
                    exercise: draft.exercise,
                    order: index,
                    sets: draft.resolvedSets,
                    measure: draft.resolvedMeasure,
                    supersetID: draft.supersetID
                )
                modelContext.insert(slot)
                slot.workout = target
            }
        }

        modelContext.saveChanges()
        dismiss()
    }
}

#if DEBUG

#Preview("New Workout") {
    CreateWorkoutView()
        .modelContainer(PreviewData.container)
}

/// Editing the seeded workout shows the populated rows: superset badges, tinted grouping and
/// the sets/reps fields carrying per-workout values rather than library defaults.
#Preview("Edit Workout") {
    CreateWorkoutView(workout: PreviewData.workout)
        .modelContainer(PreviewData.container)
}

#endif

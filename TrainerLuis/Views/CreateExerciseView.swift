import SwiftUI
import SwiftData

struct CreateExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var exercise: Exercise? // nil = create, non-nil = edit

    @State private var name = ""
    /// Which measure the form is editing. Held separately from the values so switching to
    /// Time and back doesn't discard what was typed into Reps.
    @State private var kind: SetMeasure.Kind = .reps
    /// nil while the field is blank; the placeholder shows what will be used instead.
    @State private var sets: Int?
    @State private var reps: Int?
    @State private var durationSeconds: Int?
    @State private var videoURL = ""
    @State private var notes = ""
    @State private var showingVideoPreview = false
    @State private var hasLoaded = false

    var isEditing: Bool { exercise != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Exercise Info")
                }

                MeasureDefaultsSection(
                    kind: $kind,
                    sets: $sets,
                    reps: $reps,
                    durationSeconds: $durationSeconds,
                    setsPlaceholder: setsPlaceholder,
                    repsPlaceholder: exercise?.measure.repCount ?? SetMeasure.defaultReps,
                    secondsPlaceholder: exercise?.measure.seconds ?? SetMeasure.defaultSeconds
                )

                Section {
                    TextField("YouTube URL (optional)", text: $videoURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if VideoPlayerView.isValidVideoURL(videoURL) {
                        Button("Preview Video") {
                            showingVideoPreview = true
                        }
                        .foregroundStyle(.accent)
                    }
                } header: {
                    Text("Video")
                } footer: {
                    Text("Paste a YouTube link to attach a demo video.")
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                NumberPadDoneButton()
            }
            .sheet(isPresented: $showingVideoPreview) {
                NavigationStack {
                    VideoPlayerView(urlString: videoURL)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .padding()
                        .navigationTitle("Video Preview")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingVideoPreview = false }
                            }
                        }
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Load & save

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let exercise else { return }
        name = exercise.name
        sets = exercise.sets
        kind = exercise.measure.kind
        reps = exercise.measure.repCount
        durationSeconds = exercise.measure.seconds
        videoURL = exercise.videoURL ?? ""
        notes = exercise.notes ?? ""
    }

    /// Blank fields fall back to the shared defaults, matching what their placeholders showed.
    private var resolvedMeasure: SetMeasure {
        switch kind {
        case .reps: .reps(reps ?? SetMeasure.defaultReps)
        case .time: .time(seconds: durationSeconds ?? SetMeasure.defaultSeconds)
        case .untracked: .untracked
        }
    }

    /// What a blank Sets field will save as, and therefore what its placeholder shows. An
    /// existing exercise's own value comes first, so editing a single-effort jog and saving
    /// can't silently turn it into three sets.
    private var setsPlaceholder: Int {
        exercise?.sets ?? kind.defaultSets ?? 1
    }

    private var resolvedSets: Int? {
        kind == .untracked ? nil : max(1, sets ?? setsPlaceholder)
    }

    private func save() {
        let trimmedURL = videoURL.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let exercise {
            exercise.name = name.trimmingCharacters(in: .whitespaces)
            exercise.sets = resolvedSets
            exercise.measure = resolvedMeasure
            exercise.videoURL = trimmedURL.isEmpty ? nil : trimmedURL
            exercise.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let newExercise = Exercise(
                name: name.trimmingCharacters(in: .whitespaces),
                sets: resolvedSets,
                measure: resolvedMeasure,
                videoURL: trimmedURL.isEmpty ? nil : trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(newExercise)
        }

        modelContext.saveChanges()
        dismiss()
    }
}

// MARK: - Subviews

/// The measure picker decides which fields exist, so there's no way to save a rep count
/// and a duration that disagree about what a set is.
private struct MeasureDefaultsSection: View {
    @Binding var kind: SetMeasure.Kind
    @Binding var sets: Int?
    @Binding var reps: Int?
    @Binding var durationSeconds: Int?

    /// What each blank field will save as, shown as its placeholder.
    let setsPlaceholder: Int
    let repsPlaceholder: Int
    let secondsPlaceholder: Int

    var body: some View {
        Section {
            Picker("Measured in", selection: $kind) {
                ForEach(SetMeasure.Kind.allCases) { kind in
                    Label(kind.label, systemImage: kind.symbol).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if kind != .untracked {
                NumberField(title: "Sets", value: $sets, placeholder: "\(setsPlaceholder)")
            }

            switch kind {
            case .reps:
                NumberField(title: "Reps", value: $reps, placeholder: "\(repsPlaceholder)")
            case .time:
                DurationField(
                    title: "Each set",
                    seconds: $durationSeconds,
                    placeholder: secondsPlaceholder,
                    showsTotal: true
                )
            case .untracked:
                EmptyView()
            }
        } header: {
            Text("Defaults")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        let scope = "Starting values used when this exercise is added to a workout. Each workout keeps its own, so changing these won't alter workouts you've already built."
        switch kind {
        case .reps:
            return scope
        case .time:
            return "Each set runs for this long, and can be counted down from the workout. A single set is one continuous effort — a 15 minute jog. \(scope)"
        case .untracked:
            return "No sets and nothing to count — for warm-ups and mobility work that you just tick off."
        }
    }
}

#if DEBUG

#Preview("New Exercise") {
    CreateExerciseView()
        .modelContainer(PreviewData.container)
}

#Preview("Edit Exercise") {
    CreateExerciseView(exercise: PreviewData.exercise)
        .modelContainer(PreviewData.container)
}

/// A timed exercise opens on the Time measure with its duration split into min/sec.
#Preview("Edit Timed Exercise") {
    CreateExerciseView(exercise: PreviewData.timedExercise)
        .modelContainer(PreviewData.container)
}

#endif

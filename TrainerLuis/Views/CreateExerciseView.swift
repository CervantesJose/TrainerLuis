import SwiftUI
import SwiftData

struct CreateExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var exercise: Exercise? // nil = create, non-nil = edit

    @State private var name = ""
    /// nil while the field is blank; the placeholder shows what will be used instead.
    @State private var sets: Int?
    @State private var reps: Int?
    @State private var videoURL = ""
    @State private var notes = ""
    @State private var showingVideoPreview = false
    @State private var hasLoaded = false

    private static let fallbackSets = 3
    private static let fallbackReps = 10

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

                Section {
                    NumberField(title: "Sets", value: $sets, placeholder: "\(Self.fallbackSets)")
                    NumberField(title: "Reps", value: $reps, placeholder: "\(Self.fallbackReps)")
                } header: {
                    Text("Defaults")
                } footer: {
                    Text("Starting values used when this exercise is added to a workout. Each workout keeps its own sets and reps, so changing these won't alter workouts you've already built.")
                }

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

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let exercise else { return }
        name = exercise.name
        sets = exercise.sets
        reps = exercise.reps
        videoURL = exercise.videoURL ?? ""
        notes = exercise.notes ?? ""
    }

    private func save() {
        let trimmedURL = videoURL.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSets = max(1, sets ?? Self.fallbackSets)
        let resolvedReps = max(1, reps ?? Self.fallbackReps)

        if let exercise {
            exercise.name = name.trimmingCharacters(in: .whitespaces)
            exercise.sets = resolvedSets
            exercise.reps = resolvedReps
            exercise.videoURL = trimmedURL.isEmpty ? nil : trimmedURL
            exercise.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let newExercise = Exercise(
                name: name.trimmingCharacters(in: .whitespaces),
                sets: resolvedSets,
                reps: resolvedReps,
                videoURL: trimmedURL.isEmpty ? nil : trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(newExercise)
        }

        modelContext.saveChanges()
        dismiss()
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

#endif

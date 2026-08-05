import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise
    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                LabeledContent("Sets", value: "\(exercise.sets)")
                LabeledContent("Reps", value: "\(exercise.reps)")
            } header: {
                Text("Defaults")
            } footer: {
                Text("Used when adding this exercise to a workout. Each workout stores its own sets and reps.")
            }

            if exercise.workoutUsageCount > 0 {
                Section("Usage") {
                    LabeledContent(
                        "In workouts",
                        value: "\(exercise.workoutUsageCount)"
                    )
                }
            }

            if let url = exercise.videoURL, !url.isEmpty {
                Section("Demo Video") {
                    VideoPlayerView(urlString: url)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .listRowInsets(.init(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
            }

            if let notes = exercise.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            CreateExerciseView(exercise: exercise)
        }
    }
}

#if DEBUG

/// The seeded exercise carries a video, so this covers the player row too.
#Preview("With video") {
    NavigationStack {
        ExerciseDetailView(exercise: PreviewData.exercise)
    }
    .modelContainer(PreviewData.container)
}

#endif

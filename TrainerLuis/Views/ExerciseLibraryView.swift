import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showingCreate = false

    /// Deletion is confirmed rather than immediate, because removing a library exercise also
    /// removes it from the workouts that used it.
    @State private var pendingDeletion: [Exercise] = []

    var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Tap + to add your first exercise.")
                    )
                } else {
                    List {
                        ForEach(filtered) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise, showsDefaultHint: true)
                            }
                        }
                        .onDelete(perform: requestDelete)
                    }
                    .searchable(text: $searchText, prompt: "Search exercises")
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateExerciseView()
            }
            .confirmationDialog(
                deletionTitle,
                isPresented: .init(
                    get: { !pendingDeletion.isEmpty },
                    set: { if !$0 { pendingDeletion = [] } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: confirmDelete)
                Button("Cancel", role: .cancel) { pendingDeletion = [] }
            } message: {
                Text(deletionMessage)
            }
        }
    }

    private var deletionTitle: String {
        guard let first = pendingDeletion.first else { return "Delete Exercise" }
        return pendingDeletion.count == 1 ? "Delete “\(first.name)”?" : "Delete \(pendingDeletion.count) Exercises?"
    }

    private var deletionMessage: String {
        let affected = pendingDeletion.reduce(0) { $0 + $1.workoutUsageCount }
        guard affected > 0 else { return "This can't be undone." }
        return "It's used in \(affected) workout\(affected == 1 ? "" : "s") and will be removed from \(affected == 1 ? "it" : "them") too. This can't be undone."
    }

    private func requestDelete(at offsets: IndexSet) {
        pendingDeletion = offsets.map { filtered[$0] }
    }

    private func confirmDelete() {
        for exercise in pendingDeletion {
            modelContext.delete(exercise)
        }
        pendingDeletion = []
        modelContext.saveChanges()
    }
}

#if DEBUG

#Preview {
    ExerciseLibraryView()
        .modelContainer(PreviewData.container)
}

#endif

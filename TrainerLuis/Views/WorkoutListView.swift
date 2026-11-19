import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    // The secondary sort keeps a day's several workouts in a stable, add-order sequence
    // rather than whatever the store happens to return for the tie.
    @Query(sort: [SortDescriptor(\Workout.date, order: .reverse), SortDescriptor(\Workout.createdAt)])
    private var workouts: [Workout]

    @State private var showingCreate = false
    @State private var duplicating: Workout?

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "dumbbell.fill",
                        description: Text("Tap + to create your first workout.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            NavigationLink(value: workout) {
                                WorkoutRow(workout: workout)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    duplicating = workout
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                .tint(.accentColor)
                            }
                            .contextMenu {
                                Button {
                                    duplicating = workout
                                } label: {
                                    Label("Duplicate to…", systemImage: "doc.on.doc")
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Workout", systemImage: "plus") {
                        showingCreate = true
                    }
                }
                if !workouts.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .sheet(isPresented: $showingCreate) {
                CreateWorkoutView()
            }
            .sheet(item: $duplicating) { workout in
                DuplicateWorkoutView(source: workout)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
        modelContext.saveChanges()
    }
}

#if DEBUG

#Preview {
    WorkoutListView()
        .modelContainer(PreviewData.container)
}

#endif

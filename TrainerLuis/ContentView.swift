import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Calendar", systemImage: "calendar") {
                CalendarView()
            }

            Tab("Workouts", systemImage: "dumbbell.fill") {
                WorkoutListView()
            }

            Tab("Exercises", systemImage: "figure.strengthtraining.traditional") {
                ExerciseLibraryView()
            }
        }
    }
}

#if DEBUG

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}

#endif

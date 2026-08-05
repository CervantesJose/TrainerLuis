import SwiftUI

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(workout.isCompleted ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "dumbbell.fill")
                    .foregroundStyle(workout.isCompleted ? .green : .accentColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(workout.summary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if workout.isCompleted {
                Text("Done")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG

/// The seed holds one pending and one completed workout, which is both states of the row.
#Preview("Pending and completed") {
    List(PreviewData.workouts) { workout in
        WorkoutRow(workout: workout)
    }
    .modelContainer(PreviewData.container)
}

#endif

import SwiftUI

// MARK: - Day Cell

struct DayCell: View {
    /// How many dots fit under a day before the row would outgrow the cell.
    private static let maxDots = 3

    let date: Date
    let isSelected: Bool
    let isToday: Bool

    /// One dot per workout on this day, in the order they'll be listed. Beyond
    /// ``maxDots`` the extras are dropped rather than squeezing the row.
    let dotColors: [Color]

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    Circle().fill(Color.accentColor)
                } else if isToday {
                    Circle().stroke(Color.accentColor, lineWidth: 1.5)
                }
                Text("\(cal.component(.day, from: date))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday || isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : isToday ? .accentColor : .primary)
            }
            .frame(width: 36, height: 36)

            // A clear dot holds the space on empty days so cell heights don't jitter.
            HStack(spacing: 3) {
                if dotColors.isEmpty {
                    Circle().fill(Color.clear).frame(width: 6, height: 6)
                } else {
                    ForEach(Array(dotColors.prefix(Self.maxDots).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 6, height: 6)
                    }
                }
            }
        }
        .frame(height: 50)
        .contentShape(Rectangle())
    }
}

#Preview("Every state") {
    HStack(spacing: 2) {
        DayCell(date: .now, isSelected: false, isToday: false, dotColors: [])
        DayCell(date: .now, isSelected: false, isToday: true, dotColors: [])
        DayCell(date: .now, isSelected: true, isToday: true, dotColors: [])
        DayCell(date: .now, isSelected: true, isToday: false, dotColors: [])
        DayCell(date: .now, isSelected: false, isToday: false, dotColors: [.orange])
        DayCell(date: .now, isSelected: false, isToday: false, dotColors: [.green])
        // A double day, and one that has hit the dot cap.
        DayCell(date: .now, isSelected: false, isToday: false, dotColors: [.green, .orange])
        DayCell(date: .now, isSelected: false, isToday: false, dotColors: [.green, .green, .orange, .orange])
    }
    .padding()
}

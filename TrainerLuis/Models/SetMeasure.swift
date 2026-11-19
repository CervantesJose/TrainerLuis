import Foundation

/// What one set of an exercise is counted in.
///
/// This is deliberately *not* a strength-vs-cardio distinction. Sprints are both — cardio
/// performed in sets — so a type discriminator would need a special case for them. What
/// actually varies is two independent things:
///
/// - how many sets (`sets` on ``Exercise`` / ``WorkoutExercise``), and
/// - what one set is measured in (this type).
///
/// Which covers the whole range with no special cases: bench press is 4 sets of `.reps(8)`,
/// sprints are 3 sets of `.time(seconds: 15)`, a jog is one set of `.time(seconds: 900)`,
/// and "roll out body" is `.untracked` with no sets at all.
nonisolated enum SetMeasure: Equatable, Hashable {
    /// A rep target — the classic strength prescription.
    case reps(Int)

    /// A time target, held for the length of each set. These are the sets a countdown can run.
    case time(seconds: Int)

    /// Nothing to count. Warm-ups and mobility work — "roll out body" — that are simply
    /// performed and ticked off.
    case untracked

    /// The values used when a field is left blank, so every editor agrees on the fallback.
    static let defaultSets = 3
    static let defaultReps = 10
    static let defaultSeconds = 60
}

// MARK: - Components

nonisolated extension SetMeasure {
    /// The measure axis stripped of its value, for pickers and for storing "which fields
    /// should be showing" while a value is still being typed. Shown to people as the
    /// "Measurement Type".
    ///
    /// Named `Kind` because `SetMeasure.Type` is reserved for the metatype.
    enum Kind: String, CaseIterable, Identifiable, Codable {
        case reps
        case time
        case untracked

        var id: Self { self }

        var label: String {
            switch self {
            case .reps: "Reps"
            case .time: "Timed"
            case .untracked: "Completion"
            }
        }

        var symbol: String {
            switch self {
            case .reps: "number"
            case .time: "stopwatch"
            case .untracked: "checkmark.circle"
            }
        }

        /// The set count a blank Sets field falls back to.
        ///
        /// It differs by measure because the common case does: a rep-based movement is a few
        /// sets, while a timed one is usually a single continuous effort — a 15 minute jog,
        /// not three of them. Sprints override it by typing a number.
        var defaultSets: Int? {
            switch self {
            case .reps: SetMeasure.defaultSets
            case .time: 1
            case .untracked: nil
            }
        }
    }

    var kind: Kind {
        switch self {
        case .reps: .reps
        case .time: .time
        case .untracked: .untracked
        }
    }

    var repCount: Int? {
        if case .reps(let count) = self { return count }
        return nil
    }

    var seconds: Int? {
        if case .time(let seconds) = self { return seconds }
        return nil
    }

    /// True when a countdown can be run for each set of this measure.
    var isTimed: Bool { kind == .time }

    /// Clamped to something that can actually be performed — a zero-rep or zero-second set
    /// is a typo, not a prescription.
    var normalized: SetMeasure {
        switch self {
        case .reps(let count): .reps(max(1, count))
        case .time(let seconds): .time(seconds: max(1, seconds))
        case .untracked: .untracked
        }
    }
}

// MARK: - Display

nonisolated extension SetMeasure {
    /// A duration as `m:ss`, growing to `h:mm:ss` past an hour — "0:15", "15:00", "1:05:00".
    static func timeText(_ seconds: Int) -> String {
        let duration = Duration.seconds(max(0, seconds))
        return seconds >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }

    /// The same duration with its units spelled out — "0m:15s", "15m:00s", "1h:05m:00s". Used
    /// where a duration sits next to other numbers and needs to read as a time, not a ratio.
    static func unitTimeText(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let (hours, minutes, secs) = (total / 3600, total % 3600 / 60, total % 60)
        let twoDigits = IntegerFormatStyle<Int>.number.grouping(.never).precision(.integerLength(2))
        let tail = "\(minutes.formatted(twoDigits))m:\(secs.formatted(twoDigits))s"
        return hours > 0 ? "\(hours)h:\(tail)" : "\(minutes)m:\(secs.formatted(twoDigits))s"
    }

    /// One set on its own — "8 reps", "0m:15s", or nothing to say.
    var text: String? {
        switch self {
        case .reps(let count): "\(count) rep\(count == 1 ? "" : "s")"
        case .time(let seconds): Self.unitTimeText(seconds)
        case .untracked: nil
        }
    }
}

/// Formats a full prescription: how many sets, of what.
///
/// Lives outside the models so ``Exercise`` and ``WorkoutExercise`` — which hold the same
/// three fields for different scopes — can't drift into formatting the same thing two ways.
nonisolated enum SetPrescription {
    /// e.g. "4 sets × 8 reps", "3 sets × 0m:15s", "15m:00s", "8 reps", "3 sets", or nil when
    /// there is nothing worth printing next to the exercise's name.
    static func text(sets: Int?, measure: SetMeasure) -> String? {
        let rounds = max(1, sets ?? 1)
        let setsText = rounds > 1 ? "\(rounds) sets" : nil
        guard let measureText = measure.text else { return setsText }
        guard let setsText else { return measureText }
        return "\(setsText) × \(measureText)"
    }
}

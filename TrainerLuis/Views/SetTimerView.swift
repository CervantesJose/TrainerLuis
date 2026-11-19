import AudioToolbox
import SwiftUI
import SwiftData

/// Runs a countdown for one timed exercise, recording each set as it completes.
///
/// The countdown is derived from a wall-clock `endDate` rather than counted down tick by tick.
/// Deriving from a date means locking the screen or switching apps mid-set needs no restore logic.
/// ``SetTimerNotifier`` covers alerting user when the set ends.
///
struct SetTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let slot: WorkoutExercise

    /// The instant the running set ends. Non-nil only while running.
    @State private var endDate: Date?

    /// When the running set started. This is needed for `Text(timerInterval:)`'s range.
    @State private var runStart: Date?

    /// Seconds left on a paused set. Non-nil only while paused.
    @State private var pausedRemaining: TimeInterval?

    /// Bumped each time a set runs out with the app on screen, to fire the success haptic.
    @State private var finishedSetCount = 0

    private var setLength: TimeInterval {
        TimeInterval(slot.setSeconds ?? SetMeasure.defaultSeconds)
    }

    private var isRunning: Bool { endDate != nil }

    /// Seconds showing while nothing is counting: the paused remainder, or a full set.
    private var staticRemaining: TimeInterval { pausedRemaining ?? setLength }

    private var notificationID: String { "set-timer-\(slot.id.uuidString)" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                TimerHeader(slot: slot)
                TimerDial(
                    slot: slot,
                    runStart: runStart,
                    endDate: endDate,
                    staticRemaining: staticRemaining,
                    setLength: setLength
                )
                TimerControls(
                    slot: slot,
                    isRunning: isRunning,
                    isPaused: pausedRemaining != nil,
                    onStartOrPause: { isRunning ? pause() : start() },
                    onSkip: recordSet,
                    onResetSet: resetSet,
                    onResetProgress: resetProgress
                )
                Spacer(minLength: 0)
            }
            .scenePadding()
            .navigationTitle("Set Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Restarts whenever a set starts, and cancels when one is paused or finished.
        .task(id: endDate) {
            guard let endDate else { return }
            let delay = endDate.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            completeRunningSet(alerting: true)
        }
        // The sleep above resumes late after the app is unsuspended, but returning to the foreground
        // shouldn't depend on that. The notification already alerted, so this path stays quiet.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let endDate, endDate <= Date() else { return }
            completeRunningSet(alerting: false)
        }
        .sensoryFeedback(.success, trigger: finishedSetCount)
        .onDisappear {
            SetTimerNotifier.cancel(id: notificationID)
            keepScreenAwake(false)
        }
    }

    // MARK: Actions

    private func start() {
        let remaining = staticRemaining
        guard remaining > 0 else { return }

        let now = Date()
        let target = now.addingTimeInterval(remaining)
        runStart = now
        endDate = target
        pausedRemaining = nil
        keepScreenAwake(true)

        let name = slot.exercise?.name ?? "Set"
        let body = slot.totalSets > 1
            ? "Set \(slot.nextSet ?? slot.totalSets) of \(slot.totalSets) is up."
            : "Time's up."
        Task { await SetTimerNotifier.schedule(id: notificationID, title: name, body: body, at: target) }
    }

    private func pause() {
        guard let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        runStart = nil
        SetTimerNotifier.cancel(id: notificationID)
        keepScreenAwake(false)
    }

    /// Drops back to a full set without recording it.
    private func resetSet() {
        SetTimerNotifier.cancel(id: notificationID)
        endDate = nil
        runStart = nil
        pausedRemaining = nil
        keepScreenAwake(false)
    }

    /// Banks the set whose countdown just ran out. Clearing `endDate` first is what makes this safe to call twice.
    ///
    /// - Note: Sleeping task and the return-to-foreground check both race to report the same expiry. Whichever
    /// loses finds no countdown in flight and does nothing.
    private func completeRunningSet(alerting: Bool) {
        guard endDate != nil else { return }
        resetSet()
        recordSet()

        if alerting {
            finishedSetCount += 1
            AudioServicesPlaySystemSound(1057)
        }
    }

    /// Banks one set and rearms for the next. Called directly by *Skip Set*, where one tap should always mean one set.
    private func recordSet() {
        resetSet()
        slot.recordSetDone()
        modelContext.saveChanges()
    }

    private func resetProgress() {
        resetSet()
        slot.resetProgress()
        modelContext.saveChanges()
    }

    /// A countdown you're watching shouldn't be interrupted by the display sleeping, but the override has to be lifted again or it outlives the timer.
    private func keepScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }
}

// MARK: - Subviews

private struct TimerHeader: View {
    let slot: WorkoutExercise

    var body: some View {
        VStack {
            Text(slot.exercise?.name ?? "Exercise")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(slot.isComplete ? .green : .secondary)

            if let prescription = slot.prescription {
                Text(prescription)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusText: String {
        if slot.isComplete {
            return slot.totalSets > 1 ? "All \(slot.totalSets) sets done" : "Done"
        }
        guard let next = slot.nextSet else { return "Done" }
        return slot.totalSets > 1 ? "Set \(next) of \(slot.totalSets)" : "Ready"
    }
}

/// The countdown ring and time. Animates only while a set is running.
private struct TimerDial: View {
    let slot: WorkoutExercise
    let runStart: Date?
    let endDate: Date?

    /// Seconds showing while nothing is counting: the paused remainder, or a full set.
    let staticRemaining: TimeInterval
    let setLength: TimeInterval

    /// The countdown's size, scaled with Dynamic Type from a large-title baseline.
    @ScaledMetric(relativeTo: .largeTitle) private var timeFontSize = 54.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 14)

            if let endDate, let runStart {
                // Only animates while a set is running. A paused dial has nothing to redraw.
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                    ProgressArc(
                        progress: progress(remaining: endDate.timeIntervalSince(context.date)),
                        isComplete: slot.isComplete
                    )
                }
                Text(
                    timerInterval: runStart...endDate,
                    pauseTime: nil,
                    countsDown: true,
                    showsHours: setLength >= 3600
                )
                .font(timeFont)
                .padding(.horizontal, 28)
            } else {
                ProgressArc(progress: progress(remaining: staticRemaining), isComplete: slot.isComplete)
                Text(SetMeasure.timeText(Int(staticRemaining.rounded())))
                    .font(timeFont)
                    .padding(.horizontal, 28)
            }
        }
        // The dial is fixed, so at the largest text sizes the time shrinks to fit inside it.
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .frame(width: 240, height: 240)
        .animation(.default, value: slot.setsDone)
    }

    private var timeFont: Font {
        .system(size: timeFontSize, weight: .semibold, design: .rounded).monospacedDigit()
    }

    /// How much of the current set has elapsed, 0...1.
    private func progress(remaining: TimeInterval) -> Double {
        guard setLength > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / setLength))
    }
}

private struct ProgressArc: View {
    /// How much of the set has elapsed, 0...1.
    let progress: Double
    let isComplete: Bool

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                isComplete ? Color.green : Color.accentColor,
                style: StrokeStyle(lineWidth: 14, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}

private struct TimerControls: View {
    let slot: WorkoutExercise
    let isRunning: Bool
    let isPaused: Bool
    let onStartOrPause: () -> Void
    let onSkip: () -> Void
    let onResetSet: () -> Void
    let onResetProgress: () -> Void

    var body: some View {
        VStack {
            if slot.isComplete {
                Button(action: onResetProgress) {
                    Label("Start Over", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(action: onStartOrPause) {
                    Label(
                        isRunning ? "Pause" : (isPaused ? "Resume" : startLabel),
                        systemImage: isRunning ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack {
                    Button(action: onSkip) {
                        Label("Skip Set", systemImage: "forward.end.fill")
                            .frame(maxWidth: .infinity)
                    }

                    Button(action: onResetSet) {
                        Label("Reset", systemImage: "gobackward")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!isRunning && !isPaused)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if slot.setsDone > 0 && !slot.isComplete {
                Button(
                    "Clear \(slot.setsDone) recorded set\(slot.setsDone == 1 ? "" : "s")",
                    action: onResetProgress
                )
                .font(.footnote)
            }
        }
    }

    private var startLabel: String {
        guard slot.totalSets > 1, let next = slot.nextSet else { return "Start" }
        return "Start Set \(next)"
    }
}

#if DEBUG

#Preview("Sprints — 3 × 0:15") {
    SetTimerView(slot: PreviewData.timedSlot)
        .modelContainer(PreviewData.container)
}

#Preview("Single effort — 15:00 jog") {
    SetTimerView(slot: PreviewData.runSlot)
        .modelContainer(PreviewData.container)
}

#endif

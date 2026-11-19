import SwiftUI

/// Minutes-and-seconds entry backed by a single `Int?` of seconds.
///
/// Two fields rather than one because the number pad has no colon, and seconds rather than a
/// `TimeInterval` because a set length is never fractional. The binding stays `nil` while both
/// fields are blank, so callers keep the same "blank means use the default" behaviour they get
/// from ``NumberField``.
struct DurationField: View {
    let title: String
    @Binding var seconds: Int?

    /// The default that will be used while the fields are blank.
    var placeholder: Int?

    /// Whether to print the resulting duration next to the fields. Worth it in a roomy form
    /// row where it confirms what "15" and "5" add up to; dropped inside the workout editor,
    /// where the row also carries a set count and a measure picker.
    var showsTotal: Bool = false

    @State private var minutes: Int?
    @State private var remainder: Int?

    var body: some View {
        HStack(spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // A colon between the boxes rather than "min"/"sec" labels: it reads as a clock,
            // and the labels were long enough to wrap a letter per line once a row also held
            // a Sets field.
            NumberField(title: "", value: $minutes, placeholder: "0", maxDigits: 3, width: 44)
            // Fixed, because in a narrow row SwiftUI shrinks a flexible Text before the
            // fields around it — and a colon truncated to nothing leaves two bare boxes.
            Text("m :")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()

            NumberField(title: "", value: $remainder, placeholder: "00", maxDigits: 2, width: 44)

            Text("s")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()

            if showsTotal, let readout {
                Text(readout)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(seconds == nil ? .tertiary : .secondary)
            }
        }
        .onAppear(perform: decompose)
        // Only re-split when the value changed from the outside. Rewriting the fields on
        // every keystroke would turn a typed "90" in the seconds box into "1:30" mid-edit.
        .onChange(of: seconds) { _, newValue in
            guard newValue != composed else { return }
            decompose()
        }
        .onChange(of: minutes) { _, _ in recompose() }
        .onChange(of: remainder) { _, _ in recompose() }
    }

    /// The total the fields currently describe, or nil while both are blank.
    private var composed: Int? {
        guard minutes != nil || remainder != nil else { return nil }
        return (minutes ?? 0) * 60 + (remainder ?? 0)
    }

    /// "= 0:15", or the default in parentheses while the fields are empty.
    private var readout: String? {
        if let seconds { return "= \(SetMeasure.unitTimeText(seconds))" }
        if let placeholder { return "= \(SetMeasure.unitTimeText(placeholder))" }
        return nil
    }

    private func recompose() {
        let value = composed
        guard seconds != value else { return }
        seconds = value
    }

    private func decompose() {
        guard let seconds, seconds > 0 else {
            minutes = nil
            remainder = nil
            return
        }
        // Zero shows as the placeholder rather than a literal "0", because `NumberField`
        // treats a lone zero as an empty field anyway.
        minutes = seconds / 60 == 0 ? nil : seconds / 60
        remainder = seconds % 60 == 0 ? nil : seconds % 60
    }
}

#if DEBUG

private struct DurationFieldPreview: View {
    @State private var sprint: Int? = 15
    @State private var jog: Int? = 900
    @State private var blank: Int?

    var body: some View {
        Form {
            Section("Populated") {
                DurationField(title: "Each set", seconds: $sprint, placeholder: 60, showsTotal: true)
                DurationField(title: "Each set", seconds: $jog, placeholder: 60, showsTotal: true)
            }
            Section("Blank — falls back to the default") {
                DurationField(title: "Each set", seconds: $blank, placeholder: 60, showsTotal: true)
            }
            Section("Compact — no title or total, as used in a workout row") {
                DurationField(title: "", seconds: $sprint, placeholder: 60)
            }
            Section("Bound values") {
                Text("sprint: \(sprint.map(String.init) ?? "nil")")
                Text("jog: \(jog.map(String.init) ?? "nil")")
                Text("blank: \(blank.map(String.init) ?? "nil (uses default)")")
            }
            .font(.caption.monospaced())
        }
        .toolbar { NumberPadDoneButton() }
    }
}

#Preview {
    NavigationStack { DurationFieldPreview() }
}

#endif

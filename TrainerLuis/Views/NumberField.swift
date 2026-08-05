import SwiftUI

/// A compact numeric entry field that starts **empty** instead of pre-filled.
///
/// The bound value is `nil` while the field is blank, so callers can fall back to their own
/// default — which is what `placeholder` should show. Typing is restricted to digits, so the
/// number pad's lack of a decimal/minus key is the only affordance needed.
struct NumberField: View {
    let title: String
    @Binding var value: Int?

    /// Shown while the field is empty — normally the default that will be used.
    var placeholder: String = ""
    var maxDigits: Int = 3
    var width: CGFloat = 58

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .monospacedDigit()
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .onChange(of: text) { _, newText in
                    let sanitized = Self.sanitize(newText, maxDigits: maxDigits)
                    // Rewriting `text` re-enters this handler, which then no-ops.
                    if sanitized != newText {
                        text = sanitized
                        return
                    }
                    value = sanitized.isEmpty ? nil : Int(sanitized)
                }
        }
        .onAppear(perform: syncFromValue)
        .onChange(of: value) { _, _ in syncFromValue() }
    }

    /// Mirrors an externally-changed `value` back into the text, without fighting the user
    /// while they type (`"7"` and `7` are already in agreement, so nothing is rewritten).
    private func syncFromValue() {
        guard Int(text) != value else { return }
        text = value.map(String.init) ?? ""
    }

    private static func sanitize(_ raw: String, maxDigits: Int) -> String {
        let digits = raw.filter { $0.isASCII && $0.isNumber }
        // Dropping leading zeros makes "007" read back as "7" and a lone "0" clear the
        // field — neither sets nor reps can meaningfully be zero.
        return String(digits.drop { $0 == "0" }.prefix(maxDigits))
    }
}

private struct NumberFieldPreview: View {
    @State private var sets: Int?
    @State private var reps: Int? = 8

    var body: some View {
        Form {
            Section("Empty by default") {
                NumberField(title: "Sets", value: $sets, placeholder: "3")
                NumberField(title: "Reps", value: $reps, placeholder: "10")
            }
            Section("Bound values") {
                Text("sets: \(sets.map(String.init) ?? "nil (uses default)")")
                Text("reps: \(reps.map(String.init) ?? "nil (uses default)")")
            }
        }
        .toolbar { NumberPadDoneButton() }
    }
}

#Preview {
    NavigationStack { NumberFieldPreview() }
}

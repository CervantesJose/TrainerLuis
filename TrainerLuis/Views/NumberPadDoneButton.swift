import SwiftUI

/// Dismisses the number pad, which has no return key of its own.
struct NumberPadDoneButton: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
            .fontWeight(.semibold)
        }
    }
}

#if DEBUG

#Preview("Above the number pad") {
    NavigationStack {
        Form {
            TextField("Tap to raise the number pad", text: .constant(""))
                .keyboardType(.numberPad)
        }
        .toolbar { NumberPadDoneButton() }
    }
}

#endif

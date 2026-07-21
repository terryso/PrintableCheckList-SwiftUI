import SwiftUI

struct TextEditorSheet: View {
    let title: String
    let placeholder: String?
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorIsFocused: Bool
    @State private var text: String

    init(
        title: String,
        initialText: String = "",
        placeholder: String? = nil,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 18))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .focused($editorIsFocused)

                if text.isEmpty, let placeholder {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 18))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
        .onAppear {
            editorIsFocused = true
        }
    }
}

import SwiftUI

struct NewProjectSheet: View {
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: Field?
    @State private var title = ""
    @State private var itemsText = ""

    private enum Field: Hashable {
        case title
        case items
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Example: Travel Checklist", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .title)
                        .accessibilityLabel(Text("List Name"))
                        .accessibilityIdentifier("newProjectNameField")
                        .onSubmit {
                            focusedField = .items
                        }
                } header: {
                    Text("List Name")
                } footer: {
                    if normalizedTitle.isEmpty {
                        Text("Enter a list name to continue.")
                    }
                }

                Section {
                    MultilineChecklistEditor(
                        text: $itemsText,
                        placeholder: String(localized: "One item per line"),
                        accessibilityIdentifier: "newProjectItemsEditor"
                    )
                    .frame(minHeight: 170)
                    .focused($focusedField, equals: .items)
                } header: {
                    HStack {
                        Text("Items")
                        Spacer()
                        Text("Optional")
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                } footer: {
                    Text(itemCountText)
                }
            }
            .navigationTitle(Text("New List"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onSave(title, itemsText)
                        dismiss()
                    }
                    .disabled(normalizedTitle.isEmpty)
                    .accessibilityIdentifier("createProjectButton")
                }
            }
        }
        .presentationDetents(
            dynamicTypeSize.isAccessibilitySize
                ? Set([.large])
                : Set([.medium, .large])
        )
        .presentationDragIndicator(.visible)
        .onAppear {
            focusAfterPresentation {
                focusedField = .title
            }
        }
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var itemCountText: String {
        localizedItemCount(itemTitles(in: itemsText).count)
    }
}

struct SingleLineEditorSheet: View {
    let title: String
    let fieldLabel: String
    let placeholder: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var fieldIsFocused: Bool
    @State private var text: String

    init(
        title: String,
        fieldLabel: String,
        initialText: String,
        placeholder: String,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.fieldLabel = fieldLabel
        self.placeholder = placeholder
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($fieldIsFocused)
                        .accessibilityLabel(Text(fieldLabel))
                        .accessibilityIdentifier("singleLineEditorField")
                        .onSubmit(save)
                } header: {
                    Text(fieldLabel)
                } footer: {
                    if normalizedText.isEmpty {
                        Text("Enter text to continue.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(normalizedText.isEmpty)
                        .accessibilityIdentifier("singleLineEditorSaveButton")
                }
            }
        }
        .presentationDetents(
            dynamicTypeSize.isAccessibilitySize
                ? Set([.large])
                : Set([.medium])
        )
        .presentationDragIndicator(.visible)
        .onAppear {
            focusAfterPresentation {
                fieldIsFocused = true
            }
        }
    }

    private var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !normalizedText.isEmpty else { return }
        onSave(text)
        dismiss()
    }
}

struct ItemsEditorSheet: View {
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var editorIsFocused: Bool
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MultilineChecklistEditor(
                        text: $text,
                        placeholder: String(localized: "One item per line"),
                        accessibilityIdentifier: "addItemsEditor"
                    )
                    .frame(minHeight: 230)
                    .focused($editorIsFocused)
                } header: {
                    Text("Items")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(itemCountText)
                        if itemCount == 0 {
                            Text("Enter at least one non-empty item to continue.")
                        }
                    }
                }
            }
            .navigationTitle(Text("New Item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(itemCount == 0)
                    .accessibilityIdentifier("addItemsSaveButton")
                }
            }
        }
        .presentationDetents(
            dynamicTypeSize.isAccessibilitySize
                ? Set([.large])
                : Set([.medium, .large])
        )
        .presentationDragIndicator(.visible)
        .onAppear {
            focusAfterPresentation {
                editorIsFocused = true
            }
        }
    }

    private var itemCount: Int {
        itemTitles(in: text).count
    }

    private var itemCountText: String {
        localizedItemCount(itemCount)
    }
}

private struct MultilineChecklistEditor: View {
    @Binding var text: String
    let placeholder: String
    let accessibilityIdentifier: String

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .accessibilityLabel(Text("Items"))
            .accessibilityIdentifier(accessibilityIdentifier)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
    }
}

private func itemTitles(in text: String) -> [String] {
    text
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func localizedItemCount(_ count: Int) -> String {
    let key = count == 1 ? "%ld item will be added" : "%ld items will be added"
    return String.localizedStringWithFormat(
        NSLocalizedString(key, comment: "Number of checklist items that will be added"),
        count
    )
}

private func focusAfterPresentation(_ action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
}

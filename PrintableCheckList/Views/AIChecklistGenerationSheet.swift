import SwiftUI

struct ChecklistGeneratorOverrideKey: EnvironmentKey {
    static let defaultValue: (any ChecklistGenerating)? = nil
}

extension EnvironmentValues {
    var checklistGeneratorOverride: (any ChecklistGenerating)? {
        get { self[ChecklistGeneratorOverrideKey.self] }
        set { self[ChecklistGeneratorOverrideKey.self] = newValue }
    }
}

struct AIChecklistGenerationSheet: View {
    private enum FocusedField: Hashable {
        case topic
        case generatedTitle
        case generatedItems
    }

    let mode: ChecklistGenerationMode
    let existingProject: ChecklistProject?
    let onSave: (GeneratedChecklistDraft) -> Void

    @Environment(\.checklistGeneratorOverride) private var generatorOverride
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: LLMConfigurationStore

    @FocusState private var focusedField: FocusedField?
    @State private var topic = ""
    @State private var generatedTitle = ""
    @State private var generatedItemsText = ""
    @State private var generatedSources: [ChecklistSource] = []
    @State private var didUseWebSearch = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var canContinueWithoutWebSearch = false
    @State private var searchModeOverride: ChecklistSearchMode?
    @State private var showsSettings = false
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured && generatorOverride == nil {
                    missingConfigurationView
                } else if hasResult {
                    resultForm
                } else {
                    requestForm
                }
            }
            .navigationTitle(Text(navigationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        generationTask?.cancel()
                        dismiss()
                    }
                }

                if hasResult {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveButtonTitle, action: saveResult)
                            .disabled(preparedDraft == nil)
                            .accessibilityIdentifier("saveAIGeneratedChecklistButton")
                    }
                }

            }
            .background {
                KeyboardDismissTapInstaller {
                    focusedField = nil
                }
            }
        }
        .interactiveDismissDisabled(isGenerating)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                AIConfigurationView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showsSettings = false
                            }
                        }
                    }
            }
        }
        .onDisappear {
            generationTask?.cancel()
        }
    }

    private var requestForm: some View {
        Form {
            Section {
                TextEditor(text: $topic)
                    .frame(minHeight: 150)
                    .focused($focusedField, equals: .topic)
                    .accessibilityLabel(Text("Topic and Requirements"))
                    .accessibilityIdentifier("aiTopicEditor")
                    .overlay(alignment: .topLeading) {
                        if topic.isEmpty {
                            Text(topicPlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: topic) { _, newValue in
                        if newValue.count > 1_000 {
                            topic = String(newValue.prefix(1_000))
                        }
                    }
            } header: {
                Text("Topic and Requirements")
            } footer: {
                Text(String(format: String(localized: "%ld of 1,000 characters"), topic.count))
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)

                    Button("Modify AI Configuration") {
                        openSettings()
                    }

                    if canContinueWithoutWebSearch {
                        Button("Continue Without Web Search") {
                            searchModeOverride = .off
                            performGeneration()
                        }
                        .accessibilityIdentifier("continueWithoutWebSearchButton")
                    }
                }
            }

            Section {
                Button {
                    requestGeneration()
                } label: {
                    HStack {
                        Label("Generate", systemImage: "sparkles")
                        Spacer()
                        if isGenerating {
                            ProgressView()
                        }
                    }
                }
                .disabled(!canGenerate || isGenerating)
                .accessibilityIdentifier("generateChecklistButton")

                if isGenerating {
                    Button("Cancel Generation", role: .destructive) {
                        generationTask?.cancel()
                        generationTask = nil
                        isGenerating = false
                    }
                    .accessibilityIdentifier("cancelAIGenerationButton")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = .topic
            }
        }
    }

    private var resultForm: some View {
        Form {
            if mode == .create {
                Section("List Name") {
                    TextField("List Name", text: $generatedTitle)
                        .focused($focusedField, equals: .generatedTitle)
                        .onChange(of: generatedTitle) { _, newValue in
                            if newValue.count > 80 {
                                generatedTitle = String(newValue.prefix(80))
                            }
                        }
                        .accessibilityIdentifier("aiGeneratedTitleField")
                }
            }

            Section {
                TextEditor(text: $generatedItemsText)
                    .frame(minHeight: 300)
                    .focused($focusedField, equals: .generatedItems)
                    .accessibilityLabel(Text("Generated Items"))
                    .accessibilityIdentifier("aiGeneratedItemsEditor")
            } header: {
                Text("Generated Items")
            } footer: {
                Text(generatedItemCountText)
            }

            if didUseWebSearch {
                Section {
                    if generatedSources.isEmpty {
                        Label("Web search was used for this result.", systemImage: "globe")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(generatedSources) { source in
                            Link(destination: source.url) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.title)
                                        .foregroundStyle(.primary)
                                    Text(source.url.host ?? source.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityHint(Text("Opens the source in your browser"))
                        }
                    }
                } header: {
                    Text("Sources")
                } footer: {
                    Text("Sources are provided for reference and are not saved in the checklist.")
                }
                .accessibilityIdentifier("aiSourcesSection")
            }

            Section {
                Button {
                    generatedTitle = ""
                    generatedItemsText = ""
                    generatedSources = []
                    didUseWebSearch = false
                    requestGeneration()
                } label: {
                    Label("Generate Again", systemImage: "arrow.clockwise")
                }
                .disabled(isGenerating)

                if isGenerating {
                    HStack {
                        ProgressView()
                        Text("Generating…")
                    }
                }
            } footer: {
                Text("Review and edit the result. Nothing is saved until you confirm.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var missingConfigurationView: some View {
        ContentUnavailableView {
            Label("AI Is Not Configured", systemImage: "sparkles")
        } description: {
            Text("Add a provider, model, and API Key in Settings before generating a checklist.")
        } actions: {
            Button("Open AI Settings", action: openSettings)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("openAISettingsButton")
        }
    }

    private var navigationTitle: LocalizedStringKey {
        mode == .create ? "Generate List with AI" : "Add Items with AI"
    }

    private var saveButtonTitle: LocalizedStringKey {
        mode == .create ? "Create List" : "Add Items"
    }

    private var topicPlaceholder: String {
        mode == .create
            ? String(localized: "Example: A 7-day winter trip to Japan with children")
            : String(localized: "Optional: Tell AI what may be missing")
    }

    private var hasResult: Bool {
        !generatedItemsText.isEmpty
    }

    private var canGenerate: Bool {
        mode == .supplement
            || !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var request: ChecklistGenerationRequest {
        ChecklistGenerationRequest(
            mode: mode,
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
            languageIdentifier: Locale.current.identifier,
            existingTitle: existingProject?.title,
            existingItems: Array(existingProject?.items.map(\.title).prefix(200) ?? []),
            customGenerationPrompt: settings.configuration.customGenerationPrompt,
            searchModeOverride: searchModeOverride
        )
    }

    private var rawResultItems: [String] {
        generatedItemsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var preparedDraft: GeneratedChecklistDraft? {
        try? AIResultNormalizer.normalize(
            GeneratedChecklistDraft(
                title: mode == .create ? generatedTitle : (existingProject?.title ?? ""),
                items: rawResultItems
            ),
            mode: mode,
            existingTitle: existingProject?.title,
            existingItems: existingProject?.items.map(\.title) ?? []
        )
    }

    private var generatedItemCountText: String {
        let count = rawResultItems.count
        let format = count == 1
            ? String(localized: "%ld generated item")
            : String(localized: "%ld generated items")
        return String.localizedStringWithFormat(format, count)
    }

    private func requestGeneration() {
        focusedField = nil
        errorMessage = nil
        canContinueWithoutWebSearch = false
        searchModeOverride = nil
        guard settings.isConfigured else {
            errorMessage = ChecklistGenerationError.configurationMissing.localizedDescription
            return
        }
        performGeneration()
    }

    private func performGeneration() {
        do {
            let generator: any ChecklistGenerating
            if let generatorOverride {
                generator = generatorOverride
            } else {
                generator = try ChecklistGenerationProviderFactory.make(
                    source: .userConfigured,
                    configuration: settings.configuration,
                    apiKey: settings.apiKeyForRequest()
                )
            }

            isGenerating = true
            errorMessage = nil
            canContinueWithoutWebSearch = false
            generatedSources = []
            didUseWebSearch = false
            let currentRequest = request
            generationTask = Task {
                do {
                    let result = try await generator.generate(request: currentRequest)
                    let draft = try AIResultNormalizer.normalize(
                        result.draft,
                        mode: mode,
                        existingTitle: existingProject?.title,
                        existingItems: existingProject?.items.map(\.title) ?? []
                    )
                    guard !Task.isCancelled else { return }
                    generatedTitle = draft.title
                    generatedItemsText = draft.items.joined(separator: "\n")
                    generatedSources = result.sources
                    didUseWebSearch = result.didSearch
                } catch is CancellationError {
                    // Cancellation is an explicit user action and does not need an error alert.
                } catch {
                    isGenerating = false
                    generationTask = nil
                    errorMessage = error.localizedDescription
                    canContinueWithoutWebSearch = (error as? ChecklistGenerationError)
                        == .webSearchUnavailable
                    return
                }
                isGenerating = false
                generationTask = nil
            }
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
        }
    }

    private func saveResult() {
        guard let preparedDraft else { return }
        focusedField = nil
        onSave(preparedDraft)
        dismiss()
    }

    private func openSettings() {
        focusedField = nil
        generationTask?.cancel()
        showsSettings = true
    }
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    let onTapOutside: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapOutside: onTapOutside)
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.onTapOutside = onTapOutside
        context.coordinator.attach(to: uiView.window)
    }

    static func dismantleUIView(_ uiView: InstallerView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class InstallerView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attach(to: window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTapOutside: () -> Void

        private weak var attachedWindow: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        init(onTapOutside: @escaping () -> Void) {
            self.onTapOutside = onTapOutside
        }

        func attach(to window: UIWindow?) {
            guard attachedWindow !== window else { return }
            detach()

            guard let window else { return }
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(handleTap)
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            attachedWindow = window
            self.recognizer = recognizer
        }

        func detach() {
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            attachedWindow = nil
        }

        @objc private func handleTap() {
            onTapOutside()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var touchedView = touch.view
            while let view = touchedView {
                if view is UITextField || view is UITextView {
                    return false
                }
                touchedView = view.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

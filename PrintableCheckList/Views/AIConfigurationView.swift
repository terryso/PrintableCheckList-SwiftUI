import SwiftUI

struct AIConfigurationView: View {
    @EnvironmentObject private var settings: LLMConfigurationStore

    @State private var provider: LLMProviderPreset = .glm
    @State private var baseURL = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isTesting = false
    @State private var showsTestConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var didLoad = false

    var body: some View {
        Form {
            Section {
                Picker("AI Provider", selection: $provider) {
                    ForEach(LLMProviderPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .accessibilityIdentifier("aiProviderPicker")
                .onChange(of: provider) { oldValue, newValue in
                    guard didLoad, oldValue != newValue else { return }
                    baseURL = newValue.defaultBaseURL
                    model = newValue.defaultModel
                    statusMessage = nil
                }

                TextField("Base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("aiBaseURLField")

                TextField("Model", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("aiModelField")

                SecureField(apiKeyPlaceholder, text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                    .accessibilityLabel(Text("API Key"))
                    .accessibilityIdentifier("aiAPIKeyField")
            } header: {
                Text("Connection")
            } footer: {
                Text("Your API Key is stored in this device's Keychain and is never synced or sent to the developer.")
            }

            Section {
                Button("Save Configuration") {
                    saveConfiguration()
                }
                .disabled(isTesting)
                .accessibilityIdentifier("saveAIConfigurationButton")

                Button {
                    prepareConfigurationTest()
                } label: {
                    HStack {
                        Text("Test Configuration")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isTesting)
                .accessibilityIdentifier("testAIConfigurationButton")

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Testing sends a minimal request to the selected provider and uses a small amount of your quota.")
            }

            Section {
                Button("Delete AI Configuration", role: .destructive) {
                    showsDeleteConfirmation = true
                }
                .disabled(!settings.hasAPIKey)
            } footer: {
                Text("AI requests go directly from this device to the selected provider. Configuration is saved separately on each device.")
            }
        }
        .navigationTitle(Text("AI Generation"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadConfigurationIfNeeded)
        .alert(
            Text(testConfirmationTitle),
            isPresented: $showsTestConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Send Test Request") {
                performConnectionTest()
            }
        } message: {
            Text("This sends a minimal fixed request to the AI provider and uses a small amount of your quota. It does not include checklist content.")
        }
        .confirmationDialog(
            Text("Delete AI Configuration?"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Configuration", role: .destructive) {
                deleteConfiguration()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the provider settings and API Key from this device.")
        }
    }

    private var apiKeyPlaceholder: String {
        settings.hasAPIKey
            ? String(localized: "API Key stored securely")
            : String(localized: "API Key")
    }

    private var draftConfiguration: LLMConfiguration {
        LLMConfiguration(
            provider: provider,
            baseURL: baseURL,
            model: model
        )
    }

    private func loadConfigurationIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        provider = settings.configuration.provider
        baseURL = settings.configuration.baseURL
        model = settings.configuration.model
    }

    private func saveConfiguration() {
        do {
            try settings.save(
                configuration: draftConfiguration,
                apiKey: apiKey.isEmpty ? nil : apiKey
            )
            apiKey = ""
            baseURL = settings.configuration.baseURL
            model = settings.configuration.model
            statusMessage = String(localized: "Configuration saved securely.")
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private var testConfirmationTitle: String {
        let host = settings.targetHost ?? String(localized: "Invalid address")
        return String(
            format: String(localized: "Send Test Request to %@?"),
            host
        )
    }

    private func prepareConfigurationTest() {
        do {
            try settings.save(
                configuration: draftConfiguration,
                apiKey: apiKey.isEmpty ? nil : apiKey
            )
            apiKey = ""
            baseURL = settings.configuration.baseURL
            model = settings.configuration.model
            statusMessage = nil
            errorMessage = nil
            showsTestConfirmation = true
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func performConnectionTest() {
        do {
            let key = try settings.apiKeyForRequest()
            let generator = try OpenAICompatibleChecklistGenerator(
                configuration: settings.configuration,
                apiKey: key
            )
            isTesting = true
            statusMessage = nil
            errorMessage = nil
            Task {
                do {
                    try await generator.testConnection()
                    statusMessage = String(localized: "Connection succeeded.")
                } catch {
                    errorMessage = error.localizedDescription
                }
                isTesting = false
            }
        } catch {
            isTesting = false
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func deleteConfiguration() {
        do {
            try settings.deleteConfiguration()
            provider = settings.configuration.provider
            baseURL = settings.configuration.baseURL
            model = settings.configuration.model
            apiKey = ""
            statusMessage = String(localized: "AI configuration deleted.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

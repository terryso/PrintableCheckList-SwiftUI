import MessageUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: ChecklistStore

    @State private var showsShareSheet = false
    @State private var showsMailComposer = false
    @State private var showsMailUnavailable = false
    @State private var showsAnalyticsConsent = false
    @State private var showsDeleteAnalyticsConfirmation = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AIConfigurationView()
                } label: {
                    LabeledContent {
                        Text(aiConfigurationStatus)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("AI Checklist Generation", systemImage: "sparkles")
                    }
                }
                .accessibilityIdentifier("aiConfigurationLink")
            } header: {
                Text("AI Generation")
            } footer: {
                Text("Use your own API Key to generate new lists or supplement existing ones.")
            }

            Section {
                Toggle(
                    "iCloud Sync",
                    isOn: Binding(
                        get: { store.iCloudSyncEnabled },
                        set: store.setICloudSyncEnabled
                    )
                )
                .accessibilityHint(Text("Sync checklists between devices signed in to iCloud"))
            } header: {
                Text("Sync")
            } footer: {
                Text("iCloud sync keeps your lists available on your Apple devices.")
            }

            Section {
                Toggle(
                    "Share Checklist Content for Product Analytics",
                    isOn: analyticsToggleBinding
                )
                .disabled(!store.developerAnalyticsAvailable)
                .accessibilityHint(Text("Share checklist content only after you explicitly agree"))
                .accessibilityIdentifier("analyticsSharingToggle")

                Button("Delete Shared Analytics Data", role: .destructive) {
                    showsDeleteAnalyticsConfirmation = true
                }
                .disabled(!store.developerAnalyticsAvailable)

                settingsButton("Privacy Policy") {
                    openURL(
                        URL(
                            string: "https://blog.terryso.dev/PrintableCheckList-Privacy/"
                        )!
                    )
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Checklist Analytics Settings Footer")
            }

            Section {
                settingsButton("Tell friends") {
                    showsShareSheet = true
                }

                settingsButton("Rate in AppStore") {
                    openURL(URL(string: "https://itunes.apple.com/us/app/id991595690?mt=8")!)
                }

                settingsButton("Email to support") {
                    if MFMailComposeViewController.canSendMail() {
                        showsMailComposer = true
                    } else {
                        showsMailUnavailable = true
                    }
                }

                settingsButton("Follow us on X") {
                    openURL(URL(string: "https://x.com/suchuanyi")!)
                }

                settingsButton("Open Source") {
                    openURL(URL(string: "https://github.com/terryso/PrintableCheckList-SwiftUI")!)
                }
            } header: {
                Text("Support & About")
            }

            Section {
                EmptyView()
            } footer: {
                Text(versionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textCase(nil)
                    .accessibilityLabel(Text("Version \(versionText)"))
                    .accessibilityIdentifier("appVersionText")
            }
        }
        .accessibilityIdentifier("settingsList")
        .navigationTitle(Text("Settings"))
        .sheet(isPresented: $showsShareSheet) {
            ActivityView(activityItems: [shareText])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsMailComposer) {
            MailComposer(
                subject: String(localized: "Feedback for Flash"),
                recipients: ["oxtiger@gmail.com"]
            )
        }
        .alert(
            Text("Please set up an account for sending mail on your device"),
            isPresented: $showsMailUnavailable
        ) {
            Button("Confirm", role: .cancel) {}
        }
        .alert(
            Text("Share Checklist Data?"),
            isPresented: $showsAnalyticsConsent
        ) {
            Button("Not Now", role: .cancel) {}
            Button("Agree and Turn On") {
                Task {
                    await store.setDeveloperAnalyticsEnabled(true)
                }
            }
        } message: {
            Text("Checklist Analytics Consent Message")
        }
        .confirmationDialog(
            Text("Delete Shared Analytics Data?"),
            isPresented: $showsDeleteAnalyticsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Data", role: .destructive) {
                Task {
                    await store.deleteDeveloperAnalyticsData()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This turns off sharing and deletes the checklist snapshot associated with this installation from the developer's database."
            )
        }
        .alert(
            Text("Unable to Delete Data"),
            isPresented: Binding(
                get: { store.developerAnalyticsError != nil },
                set: { isPresented in
                    if !isPresented {
                        store.clearDeveloperAnalyticsError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.developerAnalyticsError ?? "")
        }
    }

    private var analyticsToggleBinding: Binding<Bool> {
        Binding(
            get: { store.developerAnalyticsEnabled },
            set: { enabled in
                if enabled {
                    showsAnalyticsConsent = true
                } else {
                    Task {
                        await store.setDeveloperAnalyticsEnabled(false)
                    }
                }
            }
        )
    }

    private func settingsButton(
        _ titleKey: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(titleKey)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var shareText: String {
        let format = String(
            localized: "Check out 'Flash' app! The best printable check list. It's free from %@"
        )
        return String(
            format: format,
            "https://itunes.apple.com/us/app/id991595690?mt=8"
        )
    }

    private var versionText: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "-"
    }

    @EnvironmentObject private var aiSettings: LLMConfigurationStore

    private var aiConfigurationStatus: LocalizedStringKey {
        aiSettings.isConfigured ? "Configured" : "Not Configured"
    }
}

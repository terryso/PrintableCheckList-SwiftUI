import MessageUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: ChecklistStore

    @State private var showsShareSheet = false
    @State private var showsMailComposer = false
    @State private var showsMailUnavailable = false
    @State private var showsDeleteAnalyticsConfirmation = false

    var body: some View {
        List {
            Section("SHARE") {
                settingsButton("Tell friends") {
                    showsShareSheet = true
                }
            }

            Section("FEEDBACK") {
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

                settingsButton("Follow us on Twitter") {
                    openURL(URL(string: "https://twitter.com/suchuanyi")!)
                }

                settingsButton("Open Source") {
                    openURL(URL(string: "https://github.com/terryso/PrintableCheckList")!)
                }
            }

            Section("SYNC") {
                Toggle(
                    "iCloud Sync",
                    isOn: Binding(
                        get: { store.iCloudSyncEnabled },
                        set: store.setICloudSyncEnabled
                    )
                )
            }

            Section {
                Toggle(
                    "Share Anonymous Usage Data",
                    isOn: Binding(
                        get: { store.developerAnalyticsEnabled },
                        set: { enabled in
                            Task {
                                await store.setDeveloperAnalyticsEnabled(enabled)
                            }
                        }
                    )
                )
                .disabled(!store.developerAnalyticsAvailable)

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
                Text("PRIVACY")
            } footer: {
                Text(
                    "When enabled, your checklist text and an anonymous installation identifier are shared with the developer for product analytics. This is separate from iCloud Sync."
                )
            }

            Section {
                EmptyView()
            } footer: {
                Text(versionText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.76))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textCase(nil)
            }
        }
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
            }
        }
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
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "-"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "-"
        return "\(version)-\(build)(appstore)"
    }

}

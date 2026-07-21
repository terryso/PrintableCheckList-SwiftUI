import MessageUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: ChecklistStore

    @State private var showsShareSheet = false
    @State private var showsMailComposer = false
    @State private var showsMailUnavailable = false

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

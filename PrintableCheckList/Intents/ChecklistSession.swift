import Foundation

/// The checklist store App Intents and the SwiftUI app share.
///
/// Intents run in-process. A second store would overwrite `projects.json` and
/// leave the open window stale, so `PrintableCheckListApp` installs the same
/// instance the interface uses, including the UI-test store.
@MainActor
enum ChecklistSession {
    private static var installed: ChecklistStore?

    static var store: ChecklistStore {
        guard let installed else {
            preconditionFailure(
                "ChecklistSession.install must run from PrintableCheckListApp.init before an intent."
            )
        }
        return installed
    }

    static func install(_ store: ChecklistStore) {
        installed = store
    }

    /// The instance currently installed, if the app has launched.
    static var installedStore: ChecklistStore? {
        installed
    }
}

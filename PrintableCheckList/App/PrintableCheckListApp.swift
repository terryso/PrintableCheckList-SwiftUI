import SwiftUI

@main
struct PrintableCheckListApp: App {
    @StateObject private var store: ChecklistStore

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetForUITests") {
            let testFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("PrintableCheckList-UITests.json")
            try? FileManager.default.removeItem(at: testFileURL)
            _store = StateObject(
                wrappedValue: ChecklistStore(
                    storage: FileChecklistStorage(fileURL: testFileURL),
                    legacyData: nil,
                    locale: Locale(identifier: "en")
                )
            )
            return
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            _store = StateObject(wrappedValue: ChecklistStore())
            return
        }
        #endif

        _store = StateObject(
            wrappedValue: ChecklistStore(
                iCloudSyncService: ICloudSyncService(),
                developerSnapshotUploader: DeveloperSnapshotUploaderFactory.make()
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .task {
                    await store.startSyncServices()
                }
        }
    }
}

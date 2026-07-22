import SwiftUI

@main
struct PrintableCheckListApp: App {
    @StateObject private var store: ChecklistStore
    @StateObject private var aiSettings: LLMConfigurationStore
    private let generatorOverride: (any ChecklistGenerating)?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetForUITests") {
            let usesFakeGenerator = ProcessInfo.processInfo.arguments.contains(
                "-useFakeAIGeneratorForUITests"
            )
            let usesFlakyGenerator = ProcessInfo.processInfo.arguments.contains(
                "-useFlakyAIGeneratorForUITests"
            )
            let usesSlowGenerator = ProcessInfo.processInfo.arguments.contains(
                "-useSlowAIGeneratorForUITests"
            )
            let testFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("PrintableCheckList-UITests.json")
            try? FileManager.default.removeItem(at: testFileURL)
            let testDefaultsSuite = "PrintableCheckList-UITests"
            let testDefaults = UserDefaults(suiteName: testDefaultsSuite)!
            testDefaults.removePersistentDomain(forName: testDefaultsSuite)
            let testAnalyticsUploader: (any DeveloperSnapshotUploading)? =
                ProcessInfo.processInfo.arguments.contains(
                    "-enableAnalyticsConsentForUITests"
                ) ? UITestDeveloperSnapshotUploader() : nil
            _store = StateObject(
                wrappedValue: ChecklistStore(
                    storage: FileChecklistStorage(fileURL: testFileURL),
                    legacyData: nil,
                    locale: Locale(identifier: "en"),
                    userDefaults: testDefaults,
                    developerSnapshotUploader: testAnalyticsUploader
                )
            )
            let credentialStore = InMemoryLLMCredentialStore(
                apiKey: usesFakeGenerator || usesFlakyGenerator || usesSlowGenerator
                    ? "ui-test-key"
                    : nil
            )
            let testAISettings = LLMConfigurationStore(
                userDefaults: testDefaults,
                credentialStore: credentialStore
            )
            _aiSettings = StateObject(wrappedValue: testAISettings)
            if usesFlakyGenerator {
                generatorOverride = UITestFlakyChecklistGenerator()
            } else if usesSlowGenerator {
                generatorOverride = UITestSlowChecklistGenerator()
            } else if usesFakeGenerator {
                generatorOverride = UITestChecklistGenerator()
            } else {
                generatorOverride = nil
            }
            return
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            _store = StateObject(wrappedValue: ChecklistStore())
            _aiSettings = StateObject(wrappedValue: LLMConfigurationStore())
            generatorOverride = nil
            return
        }
        #endif

        _store = StateObject(
            wrappedValue: ChecklistStore(
                iCloudSyncService: ICloudSyncService(),
                developerSnapshotUploader: DeveloperSnapshotUploaderFactory.make()
            )
        )
        _aiSettings = StateObject(wrappedValue: LLMConfigurationStore())
        generatorOverride = nil
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(aiSettings)
                .environment(\.checklistGeneratorOverride, generatorOverride)
                .task {
                    await store.startSyncServices()
                }
        }
    }
}

#if DEBUG
private actor UITestDeveloperSnapshotUploader: DeveloperSnapshotUploading {
    func upload(_ projects: [ChecklistProject]) async throws {}
    func deleteSnapshot() async throws {}
}
#endif

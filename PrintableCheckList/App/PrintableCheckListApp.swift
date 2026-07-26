import SwiftUI

@main
struct PrintableCheckListApp: App {
    @StateObject private var store: ChecklistStore
    @StateObject private var aiSettings: LLMConfigurationStore
    @StateObject private var proEntitlement: ProEntitlementStore
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
            let usesManagedOperationRetryGenerator = ProcessInfo.processInfo.arguments.contains(
                "-useManagedOperationRetryGeneratorForUITests"
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
            let testStore = ChecklistStore(
                storage: FileChecklistStorage(fileURL: testFileURL),
                legacyData: nil,
                locale: Locale(identifier: "en"),
                userDefaults: testDefaults,
                developerSnapshotUploader: testAnalyticsUploader
            )
            if ProcessInfo.processInfo.arguments.contains(
                "-seedOverlongChecklistForUITests"
            ) {
                testStore.addProject(
                    title: "Overlong List",
                    itemsText: (0..<90)
                        .map { String(format: "Packing item %03ld", $0) }
                        .joined(separator: "\n")
                )
            }
            _store = StateObject(wrappedValue: testStore)
            let credentialStore = InMemoryLLMCredentialStore(
                apiKey: usesFakeGenerator || usesFlakyGenerator || usesSlowGenerator
                    || usesManagedOperationRetryGenerator
                    ? "ui-test-key"
                    : nil
            )
            let testAISettings = LLMConfigurationStore(
                userDefaults: testDefaults,
                credentialStore: credentialStore
            )
            _aiSettings = StateObject(wrappedValue: testAISettings)
            _proEntitlement = StateObject(
                wrappedValue: ProEntitlementStore(
                    entitlementOverride: usesFakeGenerator || usesFlakyGenerator || usesSlowGenerator
                        || usesManagedOperationRetryGenerator
                )
            )
            if usesManagedOperationRetryGenerator {
                generatorOverride = UITestManagedOperationRetryGenerator()
            } else if usesFlakyGenerator {
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
            _proEntitlement = StateObject(wrappedValue: ProEntitlementStore())
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
        _proEntitlement = StateObject(wrappedValue: ProEntitlementStore())
        generatorOverride = nil
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(aiSettings)
                .environmentObject(proEntitlement)
                .environment(\.checklistGeneratorOverride, generatorOverride)
                .task {
                    proEntitlement.start()
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

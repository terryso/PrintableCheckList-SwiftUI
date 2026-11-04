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
            let usesWebSearchUnavailableGenerator = ProcessInfo.processInfo.arguments.contains(
                "-useWebSearchUnavailableGeneratorForUITests"
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
            ChecklistSession.install(testStore)
            _store = StateObject(wrappedValue: testStore)
            let usesAnyUITestGenerator = usesFakeGenerator
                || usesFlakyGenerator
                || usesSlowGenerator
                || usesManagedOperationRetryGenerator
                || usesWebSearchUnavailableGenerator
            let credentialStore = InMemoryLLMCredentialStore(
                apiKey: usesAnyUITestGenerator ? "ui-test-key" : nil
            )
            let testAISettings = LLMConfigurationStore(
                userDefaults: testDefaults,
                credentialStore: credentialStore
            )
            _aiSettings = StateObject(wrappedValue: testAISettings)
            _proEntitlement = StateObject(
                wrappedValue: ProEntitlementStore(
                    entitlementOverride: usesAnyUITestGenerator
                )
            )
            if usesManagedOperationRetryGenerator {
                generatorOverride = UITestManagedOperationRetryGenerator()
            } else if usesFlakyGenerator {
                generatorOverride = UITestFlakyChecklistGenerator()
            } else if usesSlowGenerator {
                generatorOverride = UITestSlowChecklistGenerator()
            } else if usesWebSearchUnavailableGenerator {
                generatorOverride = UITestWebSearchUnavailableChecklistGenerator()
            } else if usesFakeGenerator {
                generatorOverride = UITestChecklistGenerator()
            } else {
                generatorOverride = nil
            }
            return
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let unitStore = ChecklistStore()
            ChecklistSession.install(unitStore)
            _store = StateObject(wrappedValue: unitStore)
            _aiSettings = StateObject(wrappedValue: LLMConfigurationStore())
            _proEntitlement = StateObject(wrappedValue: ProEntitlementStore())
            generatorOverride = nil
            return
        }
        #endif

        let store = ChecklistStore(
            iCloudSyncService: ICloudSyncService(),
            developerSnapshotUploader: DeveloperSnapshotUploaderFactory.make()
        )
        ChecklistSession.install(store)
        _store = StateObject(wrappedValue: store)
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

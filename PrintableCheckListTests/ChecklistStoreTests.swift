import Foundation
import UIKit
import XCTest
@testable import PrintableCheckList

private final class MemoryChecklistStorage: ChecklistStorage {
    var data: Data?

    init(data: Data? = nil) {
        self.data = data
    }

    func load() throws -> Data? {
        data
    }

    func save(_ data: Data) throws {
        self.data = data
    }
}

@MainActor
private final class MemoryICloudSyncService: ICloudSyncServicing {
    var data: Data?
    private(set) var isStarted = false
    private(set) var saveCount = 0
    private var onExternalChange: (@MainActor (Data) -> Void)?

    init(data: Data? = nil) {
        self.data = data
    }

    func start(onExternalChange: @escaping @MainActor (Data) -> Void) {
        isStarted = true
        self.onExternalChange = onExternalChange
    }

    func stop() {
        isStarted = false
    }

    func load() -> Data? {
        data
    }

    func save(_ data: Data) {
        self.data = data
        saveCount += 1
    }

    func sendExternalChange(_ data: Data) {
        self.data = data
        onExternalChange?(data)
    }
}

private actor RecordingDeveloperSnapshotUploader: DeveloperSnapshotUploading {
    private var uploads: [[ChecklistProject]] = []
    private var deletionCount = 0

    func upload(_ projects: [ChecklistProject]) async throws {
        uploads.append(projects)
    }

    func deleteSnapshot() async throws {
        deletionCount += 1
    }

    func recordedUploads() -> [[ChecklistProject]] {
        uploads
    }

    func recordedDeletionCount() -> Int {
        deletionCount
    }
}

@MainActor
final class ChecklistStoreTests: XCTestCase {
    func testCreatesLocalizedDefaultContentWhenStorageIsEmpty() {
        let storage = MemoryChecklistStorage()
        let store = ChecklistStore(
            storage: storage,
            legacyData: nil,
            locale: Locale(identifier: "zh-Hans")
        )

        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.projects[0].title, "旅行清单")
        XCTAssertEqual(store.projects[0].items.count, 16)
        XCTAssertNotNil(storage.data)
    }

    func testProjectAndItemMutationsPersist() throws {
        let storage = MemoryChecklistStorage()
        let store = ChecklistStore(
            storage: storage,
            legacyData: nil,
            locale: Locale(identifier: "en")
        )

        store.addProject(title: "Work\nList")
        let project = try XCTUnwrap(store.projects.last)
        XCTAssertEqual(project.title, "WorkList")

        store.addItems(projectID: project.id, text: "First\nSecond")
        XCTAssertEqual(store.project(id: project.id)?.items.map(\.title), ["First", "Second"])

        store.moveItems(projectID: project.id, from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(store.project(id: project.id)?.items.map(\.title), ["Second", "First"])

        let reloaded = ChecklistStore(
            storage: storage,
            legacyData: nil,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(reloaded.project(id: project.id)?.items.map(\.title), ["Second", "First"])
    }

    func testMigratesLegacyObjectiveCArchive() throws {
        let item = LegacyItemArchive()
        item.itemID = "1430671974.453793"
        item.title = "Passport"

        let project = LegacyProjectArchive()
        project.projectID = "1430671891.537601"
        project.title = "Travel Checklist"
        project.items = [item]

        let legacyData = try NSKeyedArchiver.archivedData(
            withRootObject: [project],
            requiringSecureCoding: false
        )
        let storage = MemoryChecklistStorage()
        let store = ChecklistStore(
            storage: storage,
            legacyData: legacyData,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(store.projects.map(\.title), ["Travel Checklist"])
        XCTAssertEqual(store.projects[0].items.map(\.title), ["Passport"])
        XCTAssertNotNil(storage.data)
    }

    func testPrintHTMLMatchesContentAndEscapesMarkup() {
        let project = ChecklistProject(
            title: "Travel & Work",
            items: [ChecklistItem(title: "Passport <required>")]
        )

        let html = PrintHTMLBuilder.html(for: project)

        XCTAssertTrue(html.contains("Travel &amp; Work"))
        XCTAssertTrue(html.contains("Passport &lt;required&gt;"))
        XCTAssertTrue(html.contains("class=\"checkbox\""))
    }

    func testDefaultChineseChecklistPrintsOnSingleA4Page() {
        let formatter = PrintService.printFormatter(for: DefaultContent.chineseTravelChecklist)
        let renderer = UIPrintPageRenderer()
        renderer.setValue(CGRect(x: 0, y: 0, width: 595.2, height: 842), forKey: "paperRect")
        renderer.setValue(CGRect(x: 36, y: 36, width: 523.2, height: 770), forKey: "printableRect")
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        XCTAssertEqual(renderer.numberOfPages, 1)
    }

    func testDeveloperSnapshotUploadIsDisabledWithoutConfiguration() {
        let unconfiguredTestBundle = Bundle(for: ChecklistStoreTests.self)

        XCTAssertEqual(
            DeveloperSnapshotConfiguration.fromBundle(unconfiguredTestBundle),
            .disabled
        )
    }

    func testICloudSyncImportsLegacyDataBeforeWritingNewJSON() async throws {
        let item = LegacyItemArchive()
        item.itemID = "1430671974.453793"
        item.title = "Passport"

        let project = LegacyProjectArchive()
        project.projectID = "1430671891.537601"
        project.title = "Cloud Travel"
        project.items = [item]

        let legacyData = try NSKeyedArchiver.archivedData(
            withRootObject: [project],
            requiringSecureCoding: false
        )
        let cloud = MemoryICloudSyncService(data: legacyData)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = ChecklistStore(
            storage: MemoryChecklistStorage(),
            legacyData: nil,
            locale: Locale(identifier: "en"),
            userDefaults: defaults,
            iCloudSyncService: cloud
        )

        XCTAssertEqual(cloud.saveCount, 0)
        await store.startSyncServices()
        XCTAssertEqual(store.projects.map(\.title), ["Cloud Travel"])

        store.renameProject(id: store.projects[0].id, title: "Updated")
        let savedData = try XCTUnwrap(cloud.data)
        let savedProjects = try JSONDecoder().decode(
            [ChecklistProject].self,
            from: savedData
        )
        XCTAssertEqual(savedProjects.map(\.title), ["Updated"])
        XCTAssertEqual(cloud.saveCount, 1)
    }

    func testDeveloperSnapshotUploadIsHourlyAndUsesLatestSnapshot() async throws {
        let uploader = RecordingDeveloperSnapshotUploader()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "developerAnalyticsEnabled")
        var currentDate = Date(timeIntervalSince1970: 10_000)
        let store = ChecklistStore(
            storage: MemoryChecklistStorage(),
            legacyData: nil,
            locale: Locale(identifier: "en"),
            userDefaults: defaults,
            developerSnapshotUploader: uploader,
            now: { currentDate }
        )

        store.addProject(title: "Work")
        let initialUploads = await uploader.recordedUploads()
        XCTAssertTrue(initialUploads.isEmpty)

        await store.startSyncServices()
        var uploads = await uploader.recordedUploads()
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads[0].map(\.title), ["Travel Checklist", "Work"])

        currentDate.addTimeInterval(3_599)
        store.addProject(title: "Personal")
        await store.startSyncServices()
        uploads = await uploader.recordedUploads()
        XCTAssertEqual(uploads.count, 1)

        currentDate.addTimeInterval(1)
        await store.startSyncServices()
        uploads = await uploader.recordedUploads()
        XCTAssertEqual(uploads.count, 2)
        XCTAssertEqual(
            uploads[1].map(\.title),
            ["Travel Checklist", "Work", "Personal"]
        )
    }

    func testDeveloperAnalyticsRequiresConsentBeforeUploading() async {
        let uploader = RecordingDeveloperSnapshotUploader()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = ChecklistStore(
            storage: MemoryChecklistStorage(),
            legacyData: nil,
            locale: Locale(identifier: "en"),
            userDefaults: defaults,
            developerSnapshotUploader: uploader
        )

        XCTAssertTrue(store.shouldRequestDeveloperAnalyticsConsent)
        XCTAssertFalse(store.developerAnalyticsEnabled)

        await store.startSyncServices()
        var uploads = await uploader.recordedUploads()
        XCTAssertTrue(uploads.isEmpty)

        await store.setDeveloperAnalyticsEnabled(true)
        uploads = await uploader.recordedUploads()
        XCTAssertEqual(uploads.count, 1)
        XCTAssertTrue(store.hasDeveloperAnalyticsConsentDecision)
        XCTAssertTrue(store.developerAnalyticsEnabled)
    }

    func testDisablingDeveloperAnalyticsDeletesUploadedSnapshot() async {
        let uploader = RecordingDeveloperSnapshotUploader()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "developerAnalyticsEnabled")
        let store = ChecklistStore(
            storage: MemoryChecklistStorage(),
            legacyData: nil,
            locale: Locale(identifier: "en"),
            userDefaults: defaults,
            developerSnapshotUploader: uploader
        )

        await store.startSyncServices()
        await store.setDeveloperAnalyticsEnabled(false)

        XCTAssertFalse(store.developerAnalyticsEnabled)
        XCTAssertEqual(defaults.object(forKey: "developerAnalyticsEnabled") as? Bool, false)
        let deletionCount = await uploader.recordedDeletionCount()
        XCTAssertEqual(deletionCount, 1)
    }
}

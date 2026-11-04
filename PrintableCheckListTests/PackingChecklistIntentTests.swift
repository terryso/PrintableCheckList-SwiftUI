import AppIntents
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
final class PackingChecklistIntentTests: XCTestCase {
    private var previousStore: ChecklistStore?

    override func setUp() async throws {
        previousStore = ChecklistSession.installedStore
        let storage = MemoryChecklistStorage(data: Data("[]".utf8))
        ChecklistSession.install(
            ChecklistStore(
                storage: storage,
                legacyData: nil,
                locale: Locale(identifier: "en")
            )
        )
        _ = ShortcutRouter.shared.consume()
    }

    override func tearDown() async throws {
        if let previousStore {
            ChecklistSession.install(previousStore)
        }
        _ = ShortcutRouter.shared.consume()
    }

    func testCreatePackingChecklistAndAddItems() async throws {
        let createdList = try await makeCreateIntent(
            name: "Seaside packing",
            itemsText: "Sunscreen"
        )(donate: false)

        let list = try await makeAddIntent(
            packingList: createdList,
            itemTitles: ["Hats", "Sand toys\nTowels"]
        )(donate: false)

        let project = try XCTUnwrap(ChecklistSession.store.project(id: list.id))
        XCTAssertEqual(project.title, "Seaside packing")
        XCTAssertEqual(
            project.items.map(\.title),
            ["Sunscreen", "Hats", "Sand toys", "Towels"]
        )
    }

    func testEmptyNameDoesNotCreateAChecklist() async {
        let intent = makeCreateIntent(name: "   ", itemsText: nil)
        do {
            _ = try await intent.perform()
            XCTFail("Expected an empty name to fail")
        } catch PackingChecklistIntentError.emptyName {
            XCTAssertTrue(ChecklistSession.store.projects.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEntityQueryResolvesPackingChecklistsAndItems() async throws {
        _ = try await makeCreateIntent(
            name: "Tokyo packing",
            itemsText: "Passports\nRail passes"
        )(donate: false)
        _ = try await makeCreateIntent(
            name: "School kit",
            itemsText: "Notebook"
        )(donate: false)

        let query = PackingChecklistEntityQuery()
        let matches = try await query.entities(matching: "tokyo")
        XCTAssertEqual(matches.map(\.title), ["Tokyo packing"])

        let checklist = try XCTUnwrap(matches.first)
        let items = try await PackingItemEntityQuery().entities(matching: "rail")
        XCTAssertEqual(items.map(\.title), ["Rail passes"])
        XCTAssertEqual(items.map(\.projectID), [checklist.id])

        let resolved = try await query.entities(for: [checklist.id])
        XCTAssertEqual(resolved.map(\.id), [checklist.id])
    }

    func testShowAndPrintPreviewRequestForegroundDestinations() async throws {
        let list = try await makeCreateIntent(
            name: "Weekend packing",
            itemsText: "Charger"
        )(donate: false)

        var show = ShowPackingChecklistIntent()
        show.target = list
        _ = try await show.perform()
        XCTAssertEqual(ShortcutRouter.shared.consume(), .project(list.id))

        var preview = ShowPackingPrintPreviewIntent()
        preview.packingList = list
        _ = try await preview.perform()
        XCTAssertEqual(ShortcutRouter.shared.consume(), .printPreview(list.id))
    }

    func testExportReturnsPrintReadyPDFAndRejectsAListThatDoesNotFit() async throws {
        let list = try await makeCreateIntent(
            name: "Cabin packing",
            itemsText: "Toothbrush"
        )(donate: false)

        var export = ExportPrintReadyPDFIntent()
        export.packingList = list
        export.paperSize = .a4
        let file = try await export(donate: false)
        XCTAssertEqual(file.type, .pdf)
        XCTAssertTrue(file.filename.hasSuffix(".pdf"))
        XCTAssertTrue(file.data.starts(with: Data("%PDF".utf8)))

        let titles = (0..<90).map { String(format: "Packing item %03ld", $0) }
        _ = try await makeAddIntent(packingList: list, itemTitles: titles)(donate: false)
        do {
            var overflowing = ExportPrintReadyPDFIntent()
            overflowing.packingList = list
            overflowing.paperSize = .a4
            _ = try await overflowing.perform()
            XCTFail("Expected a list that does not fit on two pages to fail")
        } catch is PrintReadyDocumentError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeCreateIntent(name: String, itemsText: String?) -> CreatePackingChecklistIntent {
        var intent = CreatePackingChecklistIntent()
        intent.name = name
        intent.itemsText = itemsText
        return intent
    }

    private func makeAddIntent(
        packingList: PackingChecklistEntity,
        itemTitles: [String]
    ) -> AddPackingItemsIntent {
        var intent = AddPackingItemsIntent()
        intent.packingList = packingList
        intent.itemTitles = itemTitles
        return intent
    }

    func testSiriAIToolPhaseStaysDeferred() {
        XCTAssertEqual(SiriAIIntentExtensionPoint.deferredSystemVersion, "27.3")
        XCTAssertFalse(
            SiriAIIntentExtensionPoint.classicIntentNames.contains("GenerateChecklistIntent")
        )
        XCTAssertTrue(
            SiriAIIntentExtensionPoint.classicIntentNames.contains("ExportPrintReadyPDFIntent")
        )
    }

}

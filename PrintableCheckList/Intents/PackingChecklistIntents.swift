import AppIntents
import UniformTypeIdentifiers

enum PackingChecklistIntentError: Error, CustomLocalizedStringResourceConvertible {
    case emptyName
    case missingChecklist
    case emptyItems

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyName:
            "Enter a name for the packing checklist."
        case .missingChecklist:
            "That packing checklist is no longer on this device."
        case .emptyItems:
            "Add at least one packing item."
        }
    }
}

/// Store operations shared by the intents. Kept on the main actor because
/// `ChecklistStore` persists synchronously.
@MainActor
enum PackingChecklistCatalog {
    static func create(name: String, itemsText: String) throws -> PackingChecklistEntity {
        guard let id = ChecklistSession.store.addProject(title: name, itemsText: itemsText),
              let project = ChecklistSession.store.project(id: id) else {
            throw PackingChecklistIntentError.emptyName
        }
        return PackingChecklistEntity(project: project)
    }

    static func addItems(projectID: UUID, itemTitles: [String]) throws -> Int {
        guard ChecklistSession.store.project(id: projectID) != nil else {
            throw PackingChecklistIntentError.missingChecklist
        }
        let count = ChecklistSession.store.addItems(
            projectID: projectID,
            text: itemTitles.joined(separator: "\n")
        )
        guard count > 0 else {
            throw PackingChecklistIntentError.emptyItems
        }
        return count
    }

    static func requireProject(_ id: UUID) throws -> ChecklistProject {
        guard let project = ChecklistSession.store.project(id: id) else {
            throw PackingChecklistIntentError.missingChecklist
        }
        return project
    }

    /// Builds the same print-ready PDF as the in-app preview. The caller
    /// returns the file to Shortcuts; nothing is sent to the print panel.
    static func printReadyFile(projectID: UUID, paper: PaperSize) throws -> IntentFile {
        let project = try requireProject(projectID)
        let document = PrintReadyDocument(project: project, paperSize: paper)
        try document.verifyFitsWithinThePageLimit()
        return IntentFile(data: document.data, filename: document.fileName, type: .pdf)
    }
}

struct ListPackingChecklistsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Packing Checklists"
    static var description = IntentDescription(
        "List printable packing checklists on this device."
    )
    static var openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    static var parameterSummary: some ParameterSummary {
        Summary("List packing checklists")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[PackingChecklistEntity]> {
        let entities = try await PackingChecklistEntityQuery().allEntities()
        return .result(
            value: entities,
            dialog: "Listed the packing checklists."
        )
    }
}

struct ListPackingItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Packing Items"
    static var description = IntentDescription(
        "List the items in a printable packing checklist."
    )
    static var openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Packing Checklist", description: "The printable packing checklist.")
    var packingList: PackingChecklistEntity

    static var parameterSummary: some ParameterSummary {
        Summary("List packing items in \(\.$packingList)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PackingItemEntity]> {
        let project = try PackingChecklistCatalog.requireProject(packingList.id)
        let items = project.items.map { PackingItemEntity(project: project, item: $0) }
        return .result(value: items, dialog: "Listed the packing items.")
    }
}

struct ShowPackingChecklistIntent: OpenIntent {
    static var title: LocalizedStringResource = "Show Packing Checklist"
    static var description = IntentDescription("Open a printable packing checklist.")

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Packing Checklist", description: "The printable packing checklist.")
    var target: PackingChecklistEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$target)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try PackingChecklistCatalog.requireProject(target.id)
        ShortcutRouter.shared.open(.project(target.id))
        return .result(dialog: "Opening the packing checklist.")
    }
}

struct ShowPackingPrintPreviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Print Preview"
    static var description = IntentDescription(
        "Open the print preview for a packing checklist."
    )
    static var openAppWhenRun = true

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Packing Checklist", description: "The printable packing checklist.")
    var packingList: PackingChecklistEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Preview \(\.$packingList)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try PackingChecklistCatalog.requireProject(packingList.id)
        ShortcutRouter.shared.open(.printPreview(packingList.id))
        return .result(dialog: "Opening the print preview.")
    }
}

struct CreatePackingChecklistIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Packing Checklist"
    static var description = IntentDescription(
        "Create a printable packing checklist. Does not set a reminder or a due date."
    )
    static var openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Checklist Name", description: "Name of the printable packing checklist.")
    var name: String

    @Parameter(
        title: "Packing Items",
        description: "One packing item per line. Leave blank to create an empty printable checklist."
    )
    var itemsText: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Create a packing checklist named \(\.$name)") {
            \.$itemsText
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PackingChecklistEntity> {
        let entity = try PackingChecklistCatalog.create(
            name: name,
            itemsText: itemsText ?? ""
        )
        return .result(value: entity, dialog: "Created a printable packing checklist.")
    }
}

struct AddPackingItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Packing Items"
    static var description = IntentDescription(
        "Add items to a printable packing checklist."
    )
    static var openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Packing Checklist", description: "The printable packing checklist.")
    var packingList: PackingChecklistEntity

    @Parameter(
        title: "Packing Items",
        description: "The packing items to add. Each entry can also contain one item per line."
    )
    var itemTitles: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$itemTitles) to \(\.$packingList)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PackingChecklistEntity> {
        _ = try PackingChecklistCatalog.addItems(
            projectID: packingList.id,
            itemTitles: itemTitles
        )
        let project = try PackingChecklistCatalog.requireProject(packingList.id)
        return .result(
            value: PackingChecklistEntity(project: project),
            dialog: "Added the packing items."
        )
    }
}

struct ExportPrintReadyPDFIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Print-Ready PDF"
    static var description = IntentDescription(
        "Export a print-ready PDF for a packing checklist so it can be shared or saved."
    )
    static var openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Packing Checklist", description: "The printable packing checklist.")
    var packingList: PackingChecklistEntity

    @Parameter(
        title: "Paper Size",
        description: "A4 or Letter. Uses the usual paper size for this region when omitted."
    )
    var paperSize: PackingPaperSize?

    static var parameterSummary: some ParameterSummary {
        Summary("Export a print-ready PDF of \(\.$packingList)") {
            \.$paperSize
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let file = try PackingChecklistCatalog.printReadyFile(
            projectID: packingList.id,
            paper: paperSize?.paperSize ?? .default()
        )
        return .result(value: file, dialog: "Exported the print-ready PDF.")
    }
}

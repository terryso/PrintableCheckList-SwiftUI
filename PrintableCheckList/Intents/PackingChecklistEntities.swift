import AppIntents
import Foundation

/// A printable packing checklist. Shortcuts resolve this when an intent asks
/// for a list. It is not a reminder and has no due date.
struct PackingChecklistEntity: AppEntity, Identifiable, Sendable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Checklist",
        synonyms: [
            "Printable Checklist",
            "打包清单",
            "可打印清单",
        ]
    )
    static var defaultQuery = PackingChecklistEntityQuery()

    var id: UUID
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(project: ChecklistProject) {
        id = project.id
        title = project.title
    }
}

struct PackingChecklistEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    func entities(for identifiers: [PackingChecklistEntity.ID]) async throws -> [PackingChecklistEntity] {
        let wanted = Set(identifiers)
        return await MainActor.run {
            ChecklistSession.store.projects
                .filter { wanted.contains($0.id) }
                .map(PackingChecklistEntity.init(project:))
        }
    }

    func entities(matching string: String) async throws -> [PackingChecklistEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return await MainActor.run {
            ChecklistSession.store.projects
                .filter { project in
                    needle.isEmpty || project.title.localizedStandardContains(needle)
                }
                .map(PackingChecklistEntity.init(project:))
        }
    }

    func allEntities() async throws -> [PackingChecklistEntity] {
        await MainActor.run {
            ChecklistSession.store.projects.map(PackingChecklistEntity.init(project:))
        }
    }
}

/// One line on a printable packing checklist. The identifier carries the
/// parent checklist so Shortcuts can resolve the item without a second store.
struct PackingItemEntity: AppEntity, Identifiable, Sendable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Checklist Item",
        synonyms: [
            "Checklist Line",
            "打包物品",
            "行李物品",
        ]
    )
    static var defaultQuery = PackingItemEntityQuery()

    var id: String
    var title: String
    var projectID: UUID
    var projectTitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(projectTitle)")
    }

    init(project: ChecklistProject, item: ChecklistItem) {
        id = "\(project.id.uuidString)/\(item.id.uuidString)"
        title = item.title
        projectID = project.id
        projectTitle = project.title
    }
}

struct PackingItemEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    func entities(for identifiers: [PackingItemEntity.ID]) async throws -> [PackingItemEntity] {
        let wanted = Set(identifiers)
        return await MainActor.run {
            Self.items(in: ChecklistSession.store.projects).filter { wanted.contains($0.id) }
        }
    }

    func entities(matching string: String) async throws -> [PackingItemEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return await MainActor.run {
            Self.items(in: ChecklistSession.store.projects).filter { item in
                needle.isEmpty
                    || item.title.localizedStandardContains(needle)
                    || item.projectTitle.localizedStandardContains(needle)
            }
        }
    }

    func allEntities() async throws -> [PackingItemEntity] {
        await MainActor.run {
            Self.items(in: ChecklistSession.store.projects)
        }
    }

    private static func items(in projects: [ChecklistProject]) -> [PackingItemEntity] {
        projects.flatMap { project in
            project.items.map { PackingItemEntity(project: project, item: $0) }
        }
    }
}

/// Paper choice for a print-ready PDF. Omitted parameters use `PaperSize.default()`.
enum PackingPaperSize: String, AppEnum {
    case a4
    case letter

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Paper Size")

    static var caseDisplayRepresentations: [PackingPaperSize: DisplayRepresentation] = [
        .a4: DisplayRepresentation(title: "A4"),
        .letter: DisplayRepresentation(title: "Letter"),
    ]

    var paperSize: PaperSize {
        switch self {
        case .a4:
            .a4
        case .letter:
            .usLetter
        }
    }
}

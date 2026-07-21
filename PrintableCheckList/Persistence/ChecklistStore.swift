import Combine
import Foundation

@MainActor
final class ChecklistStore: ObservableObject {
    @Published private(set) var projects: [ChecklistProject] = []
    @Published private(set) var persistenceError: String?
    @Published private(set) var iCloudSyncEnabled: Bool

    private let storage: ChecklistStorage
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let userDefaults: UserDefaults
    private let iCloudSyncService: (any ICloudSyncServicing)?
    private let developerSnapshotUploader: (any DeveloperSnapshotUploading)?
    private let now: () -> Date
    private var didStartICloudSync = false

    init(
        storage: ChecklistStorage = FileChecklistStorage(),
        legacyData: Data? = UserDefaults.standard.data(forKey: "keyProjects"),
        locale: Locale = .current,
        userDefaults: UserDefaults = .standard,
        iCloudSyncService: (any ICloudSyncServicing)? = nil,
        developerSnapshotUploader: (any DeveloperSnapshotUploading)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.storage = storage
        self.userDefaults = userDefaults
        self.iCloudSyncService = iCloudSyncService
        self.developerSnapshotUploader = developerSnapshotUploader
        self.now = now
        iCloudSyncEnabled = userDefaults.object(forKey: Self.iCloudEnabledKey) as? Bool ?? true
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        do {
            if let data = try storage.load() {
                projects = try decoder.decode([ChecklistProject].self, from: data)
            } else if let legacyData {
                projects = try LegacyArchiveMigration.decode(legacyData)
                persist()
            } else {
                projects = DefaultContent.projects(locale: locale)
                persist()
            }
        } catch {
            projects = DefaultContent.projects(locale: locale)
            persistenceError = error.localizedDescription
            persist()
        }
    }

    func startSyncServices() async {
        startICloudSyncIfNeeded()
        await uploadDeveloperSnapshotIfDue()
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        guard enabled != iCloudSyncEnabled else { return }
        iCloudSyncEnabled = enabled
        userDefaults.set(enabled, forKey: Self.iCloudEnabledKey)

        if enabled {
            startICloudSyncIfNeeded()
        } else {
            iCloudSyncService?.stop()
            didStartICloudSync = false
        }
    }

    func clearPersistenceError() {
        persistenceError = nil
    }

    func project(id: UUID) -> ChecklistProject? {
        projects.first { $0.id == id }
    }

    func addProject(title: String) {
        projects.append(ChecklistProject(title: normalizedSingleLine(title)))
        persist()
    }

    func renameProject(id: UUID, title: String) {
        mutateProject(id: id) { project in
            project.title = normalizedSingleLine(title)
        }
    }

    func deleteProjects(at offsets: IndexSet) {
        projects.remove(atOffsets: offsets)
        persist()
    }

    func moveProjects(from offsets: IndexSet, to destination: Int) {
        projects.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    func addItems(projectID: UUID, text: String) {
        let titles = text.components(separatedBy: .newlines)
        mutateProject(id: projectID) { project in
            project.items.append(contentsOf: titles.map { ChecklistItem(title: $0) })
        }
    }

    func renameItem(projectID: UUID, itemID: UUID, title: String) {
        mutateProject(id: projectID) { project in
            guard let itemIndex = project.items.firstIndex(where: { $0.id == itemID }) else {
                return
            }
            project.items[itemIndex].title = normalizedSingleLine(title)
        }
    }

    func deleteItems(projectID: UUID, at offsets: IndexSet) {
        mutateProject(id: projectID) { project in
            project.items.remove(atOffsets: offsets)
        }
    }

    func moveItems(projectID: UUID, from offsets: IndexSet, to destination: Int) {
        mutateProject(id: projectID) { project in
            project.items.move(fromOffsets: offsets, toOffset: destination)
        }
    }

    private func mutateProject(
        id: UUID,
        mutation: (inout ChecklistProject) -> Void
    ) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutation(&projects[projectIndex])
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(projects)
            try storage.save(data)
            persistenceError = nil
            if iCloudSyncEnabled, didStartICloudSync {
                iCloudSyncService?.save(data)
            }
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func startICloudSyncIfNeeded() {
        guard iCloudSyncEnabled, !didStartICloudSync, let iCloudSyncService else {
            return
        }
        didStartICloudSync = true
        iCloudSyncService.start { [weak self] data in
            self?.applyICloudData(data)
        }

        if let data = iCloudSyncService.load() {
            applyICloudData(data)
        } else if let data = try? encoder.encode(projects) {
            iCloudSyncService.save(data)
        }
    }

    private func applyICloudData(_ data: Data) {
        do {
            let cloudProjects: [ChecklistProject]
            if let decoded = try? decoder.decode([ChecklistProject].self, from: data) {
                cloudProjects = decoded
            } else {
                cloudProjects = try LegacyArchiveMigration.decode(data)
            }

            projects = cloudProjects
            try storage.save(encoder.encode(projects))
            persistenceError = nil
        } catch {
            persistenceError = String(
                format: String(localized: "Unable to read iCloud data: %@"),
                error.localizedDescription
            )
        }
    }

    private func uploadDeveloperSnapshotIfDue() async {
        guard let developerSnapshotUploader else { return }

        let currentDate = now()
        let lastUploadTimestamp = userDefaults.double(
            forKey: Self.developerSnapshotLastUploadKey
        )
        guard currentDate.timeIntervalSince1970 - lastUploadTimestamp
                >= Self.developerSnapshotUploadInterval else {
            return
        }

        do {
            try await developerSnapshotUploader.upload(projects)
            userDefaults.set(
                currentDate.timeIntervalSince1970,
                forKey: Self.developerSnapshotLastUploadKey
            )
        } catch {
            // This optional developer service must never block local or iCloud use.
        }
    }

    private func normalizedSingleLine(_ text: String) -> String {
        text
            .trimmingCharacters(in: .newlines)
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private static let iCloudEnabledKey = "keyEnableAutoSync"
    private static let developerSnapshotLastUploadKey = "keyLastSyncProjects"
    private static let developerSnapshotUploadInterval: TimeInterval = 60 * 60
}

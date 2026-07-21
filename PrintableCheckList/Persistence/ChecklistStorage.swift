import Foundation

protocol ChecklistStorage {
    func load() throws -> Data?
    func save(_ data: Data) throws
}

struct FileChecklistStorage: ChecklistStorage {
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let appDirectory = supportDirectory.appendingPathComponent(
            "PrintableCheckList",
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )
        fileURL = appDirectory.appendingPathComponent("projects.json")
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try Data(contentsOf: fileURL)
    }

    func save(_ data: Data) throws {
        try data.write(to: fileURL, options: .atomic)
    }
}

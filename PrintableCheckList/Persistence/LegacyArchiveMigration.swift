import Foundation

@objc(Project)
final class LegacyProjectArchive: NSObject, NSCoding {
    var projectID = ""
    var title = ""
    var items: [LegacyItemArchive] = []

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        projectID = coder.decodeObject(forKey: "self.projectId") as? String ?? ""
        title = coder.decodeObject(forKey: "self.title") as? String ?? ""
        items = coder.decodeObject(forKey: "self.items") as? [LegacyItemArchive] ?? []
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(projectID, forKey: "self.projectId")
        coder.encode(title, forKey: "self.title")
        coder.encode(items, forKey: "self.items")
    }
}
@objc(Item)
final class LegacyItemArchive: NSObject, NSCoding {
    var itemID = ""
    var title = ""

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        itemID = coder.decodeObject(forKey: "self.itemId") as? String ?? ""
        title = coder.decodeObject(forKey: "self.title") as? String ?? ""
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(itemID, forKey: "self.itemId")
        coder.encode(title, forKey: "self.title")
    }
}

enum LegacyArchiveMigration {
    static func decode(_ data: Data) throws -> [ChecklistProject] {
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(LegacyProjectArchive.self, forClassName: "Project")
        unarchiver.setClass(LegacyItemArchive.self, forClassName: "Item")
        defer { unarchiver.finishDecoding() }

        guard let projects = unarchiver.decodeObject(
            forKey: NSKeyedArchiveRootObjectKey
        ) as? [LegacyProjectArchive] else {
            throw CocoaError(.coderReadCorrupt)
        }

        return projects.map { legacyProject in
            ChecklistProject(
                id: stableUUID(for: legacyProject.projectID),
                title: legacyProject.title,
                items: legacyProject.items.map { legacyItem in
                    ChecklistItem(
                        id: stableUUID(for: legacyItem.itemID),
                        title: legacyItem.title
                    )
                }
            )
        }
    }

    private static func stableUUID(for legacyID: String) -> UUID {
        if let uuid = UUID(uuidString: legacyID) {
            return uuid
        }

        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in legacyID.utf8.enumerated() {
            let position = index % bytes.count
            bytes[position] = bytes[position] &+ byte &+ UInt8(index & 0xff)
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

import Foundation

extension Array {
    mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            remove(at: index)
        }
    }

    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let movingElements = offsets.sorted().map { self[$0] }
        let removedBeforeDestination = offsets.count { $0 < destination }
        remove(atOffsets: offsets)
        let insertionIndex = Swift.max(0, destination - removedBeforeDestination)
        insert(contentsOf: movingElements, at: Swift.min(insertionIndex, count))
    }
}

import Foundation

/// Foreground destination requested by an App Intent.
///
/// Opening a checklist or its print preview has to land in SwiftUI after
/// `openAppWhenRun` brings the app forward. The router holds that request
/// until `HomeView` applies it, including when the intent runs before the
/// first frame.
@MainActor
final class ShortcutRouter: ObservableObject {
    static let shared = ShortcutRouter()

    enum Destination: Equatable {
        case project(UUID)
        case printPreview(UUID)
    }

    @Published private(set) var destination: Destination?

    func open(_ destination: Destination) {
        self.destination = destination
    }

    func consume() -> Destination? {
        defer { destination = nil }
        return destination
    }
}
